//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DistanceAnalysis.swift
//  PopulationGenetics
//
//  Computes a pairwise distance matrix among a dataset's adults or among the
//  strata of one level, by any of `DistanceSpec.Measure`'s distances. Genetic
//  measures use the adults genotyped at some locus (`GeneticDistances` has
//  the missing-data rules); great-circle distance uses the adults with
//  coordinates. For great-circle distance a stratum sits at the mean of its distinct
//  coordinates, as gstudio's `strata_coordinates()` places it, so a stratum
//  whose individuals share one location sits exactly there however many were
//  sampled. Strata keep the order they first appear in, as gstudio's do, and
//  an individual matrix keeps the dataset's order, with each row's innermost
//  stratum recorded so the heatmap can mark the strata.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import CoreLocation
import Foundation
import Graph
import Matrix

/// A pairwise distance matrix to compute from a dataset's coordinates or genotypes.
public struct DistanceAnalysis: Sendable {

    /// One unit of the matrix: an adult, or a stratum and its adults.
    private struct Unit: Sendable {
        let name: String
        let ordinals: [Int]
        let coordinate: CLLocationCoordinate2D?
        let group: String?
    }

    /// The fewest individuals a stratum needs to be a node of the population graph that cGD is measured through.
    public static let minimumGraphStratumSize = PopulationGraphBuilder.minimumPopulationSize

    /// What is computed.
    public let spec: DistanceSpec
    /// Whether the adults are the mothers of parent/offspring data.
    public let isParentOffspring: Bool
    private let genotypes: GenotypeMatrix
    private let units: [Unit]
    private let omitted: [String]
    private let omissionReason: String

    // MARK: - Initialization

    /// Prepares a matrix, or returns `nil` when the measure doesn't work at the spec's level or the dataset has too
    /// few units there (two, or for cGD three strata).
    ///
    /// - Parameters:
    ///   - spec: What to compute.
    ///   - dataset: The genotypes, with their coordinates and strata.
    public init?(spec: DistanceSpec, dataset: ImportedDataset) {
        guard spec.isValid else { return nil }
        let individuals = dataset.matrix.individuals
        let adults = dataset.adultOrdinals
        let measure = spec.measure
        let isEligible: (Int) -> Bool = measure.isGenetic
            ? { ordinal in dataset.matrix.columns.contains { !$0.isEmpty(at: ordinal) } }
            : { individuals[$0].coordinate != nil }
        isParentOffspring = !dataset.parentage.families.isEmpty
        genotypes = dataset.matrix
        self.spec = spec
        var units: [Unit] = []
        var omitted: [String] = []
        if spec.isAmongIndividuals {
            for (ordinal, name) in zip(adults, Self.uniqueNames(adults.map { individuals[$0].name })) {
                guard isEligible(ordinal) else {
                    omitted.append(name)
                    continue
                }
                units.append(Unit(name: name, ordinals: [ordinal], coordinate: individuals[ordinal].coordinate,
                                  group: dataset.strata[individuals[ordinal].id]?.last?.name))
            }
        } else {
            let minimum = measure == .cgd ? Self.minimumGraphStratumSize : 1
            for (name, members) in Self.strata(at: spec.level, of: adults, in: dataset) {
                let eligible = members.filter(isEligible)
                guard eligible.count >= minimum else {
                    omitted.append(name)
                    continue
                }
                let coordinate = measure.isGenetic ? nil : Self.centroid(of: eligible, in: dataset)
                units.append(Unit(name: name, ordinals: eligible, coordinate: coordinate, group: nil))
            }
        }
        self.units = units
        self.omitted = omitted
        if measure == .cgd {
            omissionReason = "fewer than \(Self.minimumGraphStratumSize) genotyped individuals"
        } else {
            omissionReason = measure.isGenetic ? "not genotyped" : "no coordinates"
        }
        guard units.count >= (measure == .cgd ? 3 : 2) else { return nil }
    }

    /// The strata at a level, in the order they first appear, each with its adults.
    private static func strata(at level: String, of adults: [Int],
                               in dataset: ImportedDataset) -> [(name: String, members: [Int])] {
        var order: [String] = []
        var members: [String: [Int]] = [:]
        for ordinal in adults {
            let id = dataset.matrix.individuals[ordinal].id
            guard let stratum = dataset.strata[id]?.first(where: { $0.level == level })?.name else { continue }
            if members[stratum] == nil { order.append(stratum) }
            members[stratum, default: []].append(ordinal)
        }
        return order.map { ($0, members[$0] ?? []) }
    }

    /// The mean of the adults' distinct coordinates, as gstudio's `strata_coordinates()` places a stratum.
    private static func centroid(of adults: [Int], in dataset: ImportedDataset) -> CLLocationCoordinate2D? {
        var points: [CLLocationCoordinate2D] = []
        for ordinal in adults {
            guard let coordinate = dataset.matrix.individuals[ordinal].coordinate,
                  !points.contains(where: {
                      $0.latitude == coordinate.latitude && $0.longitude == coordinate.longitude
                  }) else { continue }
            points.append(coordinate)
        }
        guard !points.isEmpty else { return nil }
        let count = Double(points.count)
        return CLLocationCoordinate2D(latitude: points.map(\.latitude).reduce(0, +) / count,
                                      longitude: points.map(\.longitude).reduce(0, +) / count)
    }

    /// Names that are unique: empty names become "Individual n", and repeats get " (2)", " (3)" and so on.
    private static func uniqueNames(_ names: [String]) -> [String] {
        var seen: [String: Int] = [:]
        return names.enumerated().map { index, raw in
            let name = raw.trimmingCharacters(in: .whitespaces).isEmpty ? "Individual \(index + 1)" : raw
            let count = seen[name, default: 0] + 1
            seen[name] = count
            return count == 1 ? name : "\(name) (\(count))"
        }
    }

    // MARK: - Running

    /// The number of units the matrix is among.
    public var count: Int {
        units.count
    }

    /// Computes the matrix.
    ///
    /// - Returns: The distances, each row's group, and the units left out; `nil` only when cGD's population graph
    ///   can't be estimated.
    public func run() -> DistanceResult? {
        let names = units.map(\.name)
        guard let distance = distances() else { return nil }
        var matrix = UnitDistanceMatrix(groupNames: names)
        for i in units.indices {
            for j in (i + 1)..<units.count { matrix[i, j] = distance(i, j) }
        }
        let groups = spec.isAmongIndividuals && units.contains { $0.group != nil } ? units.map { $0.group ?? "" } : nil
        return DistanceResult(spec: spec, matrix: matrix, groups: groups, omitted: omitted,
                              omissionReason: omissionReason, isParentOffspring: isParentOffspring)
    }

    /// The distance between units `i` and `j`, by the spec's measure.
    private func distances() -> ((Int, Int) -> Double)? {
        let first = units.map { $0.ordinals[0] }
        switch spec.measure {
        case .greatCircle:
            let coordinates = units.compactMap(\.coordinate)
            return { GreatCircle.distance(coordinates[$0], coordinates[$1]) }
        case .amova:
            let matrix = GeneticDistances.amova(matrix: genotypes, ordinals: first)
            return { matrix[$0, $1] }
        case .bray:
            let matrix = GeneticDistances.brayCurtis(matrix: genotypes, ordinals: first)
            return { matrix[$0, $1] }
        case .nei, .cavalli, .dps, .euclidean:
            let measure: GeneticDistances.FrequencyMeasure = switch spec.measure {
            case .nei: .nei
            case .cavalli: .cavalli
            case .dps: .dps
            default: .euclidean
            }
            let matrix = GeneticDistances.frequencyDistance(measure, matrix: genotypes, strata: units.map(\.ordinals))
            return { matrix[$0, $1] }
        case .phiST:
            let ordinals = units.flatMap(\.ordinals)
            let labels = units.flatMap { unit in unit.ordinals.map { _ in unit.name } }
            let phi = PairwisePhiST(distance: GeneticDistances.amova(matrix: genotypes, ordinals: ordinals),
                                    strata: labels)
            let names = units.map(\.name)
            return { phi[names[$0], names[$1]] ?? .nan }
        case .cgd:
            let ordinals = units.flatMap(\.ordinals)
            let groups = units.flatMap { unit in unit.ordinals.map { _ in unit.name } }
            let multivariate = genotypes.multivariateMatrix()
            let x = multivariate.submatrix(ordinals, Array(0..<multivariate.cols))
            guard let graph = PopulationGraph(x: x, groups: groups) else { return nil }
            let paths = graph.weightedDistanceMatrix()
            let index = Dictionary(uniqueKeysWithValues: paths.rowNames.enumerated().map { ($1, $0) })
            let names = units.map(\.name)
            return { i, j in
                guard let a = index[names[i]], let b = index[names[j]] else { return .nan }
                return paths[a, b]
            }
        }
    }
}
