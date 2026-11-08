//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DistanceOptions.swift
//  PopulationGenetics
//
//  The distance matrices a dataset offers. Distances are among the adults:
//  every individual in adult data, and only the mothers in parent/offspring
//  data, since offspring are sampled at their mother's location and are
//  their mother's genes plus a pollen donor's. Strata are the levels the
//  adults carry. Great-circle distance counts the units with coordinates,
//  the genetic measures the units genotyped at some locus, and cGD the strata
//  with enough individuals for the population graph. A level needs two such
//  units (cGD three) to make a matrix.
//
//  Matrices are computed when they're needed, never stored: even 5,000
//  individuals take under a tenth of a second, while reading the same matrix
//  back from a file takes seconds and hundreds of megabytes.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// What distance matrices a dataset offers: the levels, the measures at each, and how many units each has.
public struct DistanceOptions: Sendable, Equatable {

    /// Whether the adults are the mothers of parent/offspring data.
    public let isParentOffspring: Bool
    /// The levels a matrix can be among, by some measure: ``DistanceSpec/individualsLevel`` first, then the adults'
    /// stratum levels, outermost first.
    public let levels: [String]
    /// The number of adults.
    public let adultCount: Int
    /// The number of adults with coordinates.
    public let locatedCount: Int
    /// The number of adults genotyped at some locus.
    public let genotypedCount: Int
    /// The units at each level with coordinates.
    private let located: [String: Int]
    /// The units at each level genotyped at some locus.
    private let genotyped: [String: Int]
    /// The strata at each level with enough genotyped individuals to be a node of the population graph.
    private let graphable: [String: Int]

    // MARK: - Initialization

    /// Reads what a dataset offers.
    ///
    /// - Parameter dataset: The genotypes, with their coordinates and strata.
    public init(dataset: ImportedDataset) {
        isParentOffspring = !dataset.parentage.families.isEmpty
        let adults = dataset.adultOrdinals
        let individuals = dataset.matrix.individuals
        let hasLocation = adults.filter { individuals[$0].coordinate != nil }
        let hasGenotype = adults.filter { ordinal in dataset.matrix.columns.contains { !$0.isEmpty(at: ordinal) } }
        adultCount = adults.count
        locatedCount = hasLocation.count
        genotypedCount = hasGenotype.count

        var levels: [String] = []
        for ordinal in adults {
            for reference in dataset.strata[individuals[ordinal].id] ?? [] where !levels.contains(reference.level) {
                levels.append(reference.level)
            }
        }
        /// The number of individuals in each stratum of each level, among some adults.
        func sizes(_ ordinals: [Int]) -> [String: [String: Int]] {
            var sizes: [String: [String: Int]] = [:]
            for ordinal in ordinals {
                for reference in dataset.strata[individuals[ordinal].id] ?? [] {
                    sizes[reference.level, default: [:]][reference.name, default: 0] += 1
                }
            }
            return sizes
        }
        let locatedSizes = sizes(hasLocation)
        let genotypedSizes = sizes(hasGenotype)
        var located = [DistanceSpec.individualsLevel: hasLocation.count]
        var genotyped = [DistanceSpec.individualsLevel: hasGenotype.count]
        var graphable: [String: Int] = [:]
        for level in levels {
            located[level] = locatedSizes[level]?.count ?? 0
            genotyped[level] = genotypedSizes[level]?.count ?? 0
            graphable[level] = genotypedSizes[level]?.values
                .filter { $0 >= DistanceAnalysis.minimumGraphStratumSize }.count ?? 0
        }
        self.located = located
        self.genotyped = genotyped
        self.graphable = graphable
        let all = [DistanceSpec.individualsLevel] + levels
        self.levels = all.filter { level in DistanceSpec.Measure.allCases.contains { Self.offers($0, level, located,
                                                                                               genotyped, graphable) } }
    }

    /// Whether a measure has enough units at a level.
    private static func offers(_ measure: DistanceSpec.Measure, _ level: String, _ located: [String: Int],
                               _ genotyped: [String: Int], _ graphable: [String: Int]) -> Bool {
        guard DistanceSpec(measure: measure, level: level).isValid else { return false }
        switch measure {
        case .greatCircle: return (located[level] ?? 0) >= 2
        case .cgd: return (graphable[level] ?? 0) >= 3
        default: return (genotyped[level] ?? 0) >= 2
        }
    }

    // MARK: - Choices

    /// Whether the dataset has any matrix to offer.
    public var hasMatrices: Bool {
        !levels.isEmpty
    }

    /// Whether any adults have coordinates enough for a great-circle matrix.
    public var hasCoordinates: Bool {
        levels.contains { offers(.greatCircle, at: $0) }
    }

    /// Whether a measure can be computed at a level.
    ///
    /// - Parameters:
    ///   - measure: The measure.
    ///   - level: A level from ``levels``.
    /// - Returns: `true` when the level has enough units for it.
    public func offers(_ measure: DistanceSpec.Measure, at level: String) -> Bool {
        Self.offers(measure, level, located, genotyped, graphable)
    }

    /// The measures a level offers, physical first.
    ///
    /// - Parameter level: A level from ``levels``.
    /// - Returns: The measures, in ``DistanceSpec/Measure`` order.
    public func measures(at level: String) -> [DistanceSpec.Measure] {
        DistanceSpec.Measure.allCases.filter { offers($0, at: level) }
    }

    /// Whether a spec can be computed.
    ///
    /// - Parameter spec: The spec.
    /// - Returns: `true` when its level offers its measure.
    public func offers(_ spec: DistanceSpec) -> Bool {
        offers(spec.measure, at: spec.level)
    }

    /// The number of units a measure is among at a level.
    ///
    /// - Parameters:
    ///   - level: A level from ``levels``.
    ///   - measure: The measure.
    /// - Returns: The located, genotyped or (cGD) graphable units.
    public func unitCount(at level: String, for measure: DistanceSpec.Measure) -> Int {
        switch measure {
        case .greatCircle: located[level] ?? 0
        case .cgd: graphable[level] ?? 0
        default: genotyped[level] ?? 0
        }
    }

    /// The spec the page starts with: great-circle distance among the innermost located stratum level (or the
    /// individuals), or without coordinates Nei's distance among the innermost stratum level, or AMOVA distance
    /// among the individuals.
    public var defaultSpec: DistanceSpec? {
        if let level = levels.last(where: { offers(.greatCircle, at: $0) }) {
            return DistanceSpec(measure: .greatCircle, level: level)
        }
        if let level = levels.last(where: { offers(.nei, at: $0) }) {
            return DistanceSpec(measure: .nei, level: level)
        }
        return offers(.amova, at: DistanceSpec.individualsLevel)
            ? DistanceSpec(measure: .amova, level: DistanceSpec.individualsLevel) : nil
    }

    /// The same spec at another level, keeping its measure when the level offers it.
    ///
    /// - Parameters:
    ///   - spec: The current spec.
    ///   - level: The level to move to.
    /// - Returns: The spec at `level`, with its measure or else the level's first.
    public func spec(_ spec: DistanceSpec, movedTo level: String) -> DistanceSpec {
        let measures = measures(at: level)
        let measure = measures.contains(spec.measure) ? spec.measure : (measures.first ?? spec.measure)
        return DistanceSpec(measure: measure, level: level)
    }

    /// How a level is named in the controls: "Individuals", "Mothers", or the level itself.
    ///
    /// - Parameter level: A level from ``levels``.
    /// - Returns: Its label.
    public func label(for level: String) -> String {
        guard level == DistanceSpec.individualsLevel else { return level }
        return isParentOffspring ? "Mothers" : DistanceSpec.individualsLevel
    }
}
