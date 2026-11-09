//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopulationGraphBuilder.swift
//  PopulationGenetics
//
//  Estimates a population graph from a project's genotypes, and tells whether
//  a saved graph still matches them. Eligibility is derived from the current
//  data rather than fixed at import, since editing a population name can
//  change a population's size.
//
//  Nodes are the strata of one level, the innermost by default, so a project with nested strata (clusters within
//  treatments) can draw its graph among either. Only adults are nodes' members: offspring share their mothers' alleles
//  and would inflate the within-node variance the graph rests on. Their own graph is the pollination graph of
//  `PopulationGraphBuilder+PollenPools.swift`, among maternal families.
//
//  Created by Rodney Dyer on 2026.10.24.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import CoreLocation
import Foundation
import Matrix

/// Builds population graphs (Dyer & Nason 2004) from imported genotypes.
public enum PopulationGraphBuilder {

    /// Which populations can be nodes in the graph.
    public struct Eligibility: Sendable {

        /// A population and its sample size.
        public struct Population: Identifiable, Sendable {
            /// The population's name.
            public let name: String
            /// The number of individuals sampled.
            public let count: Int

            /// The population's name.
            public var id: String { name }
        }

        /// Populations with at least ``PopulationGraphBuilder/minimumPopulationSize``
        /// individuals, in natural sort order.
        public let included: [Population]

        /// Populations too small to be nodes, in natural sort order.
        public let excluded: [Population]

        /// Whether there are enough eligible populations to estimate a graph.
        public var canEstimate: Bool { included.count >= PopulationGraphBuilder.minimumPopulationCount }

        /// Sorts a dataset's strata at one level by whether they are big enough.
        ///
        /// - Parameters:
        ///   - dataset: The genotypes, with strata.
        ///   - level: The strata level whose strata are nodes, or `nil` for the innermost.
        public init(dataset: ImportedDataset, level: String? = nil) {
            var counts: [String: Int] = [:]
            if level == PopulationGraphBuilder.pollenPoolLevel {
                // A pollen pool's members are its offspring's paternal gametes.
                for family in dataset.familiesWithOffspring { counts[family.id] = family.offspring.count }
            }
            for ordinal in dataset.adultOrdinals where level != PopulationGraphBuilder.pollenPoolLevel {
                let name = PopulationGraphBuilder.name(at: ordinal, level: level, in: dataset)
                guard !name.isEmpty else { continue }
                counts[name, default: 0] += 1
            }
            let populations = counts.keys
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                .map { Population(name: $0, count: counts[$0] ?? 0) }
            included = populations.filter { $0.count >= PopulationGraphBuilder.minimumPopulationSize }
            excluded = populations.filter { $0.count < PopulationGraphBuilder.minimumPopulationSize }
        }
    }

    /// The fewest individuals a population needs to be a node: the graph uses
    /// within-population variance, which must be non-zero.
    public static let minimumPopulationSize = 3

    /// The fewest eligible populations needed to estimate a graph.
    public static let minimumPopulationCount = 3

    /// The `graphValues` key holding the fingerprint of the genotypes and
    /// population assignments a graph was estimated from.
    public static let fingerprintKey = "inputFingerprint"

    // MARK: - Estimating

    /// Estimates a population graph among the eligible strata of one level.
    ///
    /// Nodes are placed at their stratum's centroid, when it has coordinates.
    ///
    /// - Parameters:
    ///   - dataset: The genotypes, with strata and coordinates.
    ///   - level: The strata level whose strata are nodes, or `nil` for the innermost.
    /// - Returns: The graph, stamped with the dataset's fingerprint, or `nil` if
    ///   there are too few eligible strata or the decomposition fails.
    public static func estimate(from dataset: ImportedDataset, level: String? = nil) -> PopulationGraphDataset? {
        if level == pollenPoolLevel { return estimatePollenPools(from: dataset) }
        let eligibility = Eligibility(dataset: dataset, level: level)
        guard eligibility.canEstimate else { return nil }
        let names = Set(eligibility.included.map(\.name))
        let rows = dataset.adultOrdinals.filter { names.contains(name(at: $0, level: level, in: dataset)) }
        let multivariate = dataset.matrix.multivariateMatrix()
        let x = multivariate.submatrix(rows, Array(0..<multivariate.cols))
        let groups = rows.map { name(at: $0, level: level, in: dataset) }
        guard let graph = PopulationGraph(x: x, groups: groups) else { return nil }

        let centroids = centroids(in: dataset, level: level)
        // Each node's lineage, from the outermost level down to its own.
        var lineages: [String: [StratumReference]] = [:]
        for ordinal in rows {
            let lineage = dataset.strata[dataset.matrix.individuals[ordinal].id] ?? []
            guard let depth = level.map({ level in lineage.firstIndex { $0.level == level } })
                ?? lineage.indices.last else { continue }
            let name = lineage[depth].name
            if lineages[name] == nil { lineages[name] = Array(lineage[...depth]) }
        }
        var nodeStrata: [UUID: [StratumReference]] = [:]
        for node in graph.nodes {
            node.coordinate = centroids[node.name]
            nodeStrata[node.id] = lineages[node.name]
        }
        return PopulationGraphDataset(graph: graph, nodeStrata: nodeStrata,
                                      graphValues: [fingerprintKey: fingerprint(of: dataset, level: level)],
                                      loci: dataset.matrix.loci)
    }

    // MARK: - Staleness

    /// Whether a graph was estimated from different genotypes or population assignments than the
    /// dataset now holds.
    ///
    /// Coordinates don't count: nodes are drawn at the current centroids.
    ///
    /// - Parameters:
    ///   - graph: A saved graph.
    ///   - dataset: The current genotypes.
    /// - Returns: `true` if the graph should be re-estimated; `false` if it
    ///   matches, or carries no fingerprint to compare.
    public static func isStale(_ graph: PopulationGraphDataset, for dataset: ImportedDataset) -> Bool {
        guard let stamped = graph.graphValues[fingerprintKey] else { return false }
        return stamped != fingerprint(of: dataset, level: level(of: graph))
    }

    /// A stable FNV-1a hash of every adult's stratum at one level and genotypes,
    /// truncated to 53 bits so it survives storage as a `Double`.
    ///
    /// - Parameters:
    ///   - dataset: The genotypes, with strata.
    ///   - level: The strata level whose strata are nodes, or `nil` for the innermost.
    /// - Returns: The fingerprint.
    public static func fingerprint(of dataset: ImportedDataset, level: String? = nil) -> Double {
        if level == pollenPoolLevel { return pollenPoolFingerprint(of: dataset) }
        return fingerprint(of: dataset.adultOrdinals.map { (name(at: $0, level: level, in: dataset), $0) }, in: dataset)
    }

    /// A stable FNV-1a hash of some individuals' groups and genotypes, truncated to 53 bits so it survives storage
    /// as a `Double`.
    ///
    /// - Parameters:
    ///   - members: Each individual's group and row, in a stable order.
    ///   - dataset: The genotypes.
    /// - Returns: The fingerprint.
    static func fingerprint(of members: [(group: String, ordinal: Int)], in dataset: ImportedDataset) -> Double {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        func mix(_ text: String) {
            for byte in text.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3 }
            hash = (hash ^ 0xff) &* 0x100_0000_01b3
        }
        for (group, ordinal) in members {
            mix(group)
            for locus in 0..<dataset.matrix.locusCount {
                if let (left, right) = dataset.alleleLabels(at: ordinal, locus: locus) {
                    mix(left)
                    mix(right)
                } else {
                    mix("")
                }
            }
        }
        return Double(hash >> 11)
    }

    // MARK: - Levels

    /// The strata levels whose strata can be nodes, outermost first, then ``pollenPoolLevel`` when mothers have
    /// offspring.
    ///
    /// - Parameter dataset: The genotypes, with strata.
    /// - Returns: The levels the adults are assigned to.
    public static func levels(in dataset: ImportedDataset) -> [String] {
        var levels: [String] = []
        for ordinal in dataset.adultOrdinals {
            for reference in dataset.strata[dataset.matrix.individuals[ordinal].id] ?? []
            where !levels.contains(reference.level) {
                levels.append(reference.level)
            }
        }
        if !dataset.familiesWithOffspring.isEmpty { levels.append(pollenPoolLevel) }
        return levels
    }

    /// The level whose strata are a graph's nodes, read from their lineages.
    ///
    /// - Parameter graph: A saved graph.
    /// - Returns: The level, or `nil` if the nodes carry no lineage.
    public static func level(of graph: PopulationGraphDataset) -> String? {
        graph.nodeStrata.values.lazy.compactMap(\.last?.level).first
    }

    /// Each located stratum's centroid at one level, by name, from its adults.
    ///
    /// - Parameters:
    ///   - dataset: The genotypes, with coordinates.
    ///   - level: The strata level, or `nil` for the innermost.
    /// - Returns: The centroids.
    public static func centroids(in dataset: ImportedDataset,
                                 level: String? = nil) -> [String: CLLocationCoordinate2D] {
        if level == pollenPoolLevel { return pollenPoolCentroids(in: dataset) }
        var sums: [String: (latitude: Double, longitude: Double, count: Double)] = [:]
        for ordinal in dataset.adultOrdinals {
            let individual = dataset.matrix.individuals[ordinal]
            let name = name(at: ordinal, level: level, in: dataset)
            guard !name.isEmpty, let latitude = individual.latitude, let longitude = individual.longitude else {
                continue
            }
            let sum = sums[name] ?? (0, 0, 0)
            sums[name] = (sum.latitude + latitude, sum.longitude + longitude, sum.count + 1)
        }
        return sums.mapValues { CLLocationCoordinate2D(latitude: $0.latitude / $0.count,
                                                       longitude: $0.longitude / $0.count) }
    }

    /// An individual's stratum at one level.
    ///
    /// - Parameters:
    ///   - ordinal: The individual's row.
    ///   - level: The level, or `nil` for the innermost.
    ///   - dataset: The genotypes, with strata.
    /// - Returns: The stratum's name, or `""` if the individual has none at that level.
    static func name(at ordinal: Int, level: String?, in dataset: ImportedDataset) -> String {
        guard let level else { return dataset.populationName(at: ordinal) }
        return dataset.strata[dataset.matrix.individuals[ordinal].id]?.first { $0.level == level }?.name ?? ""
    }
}
