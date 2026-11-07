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

        /// Sorts a dataset's populations by whether they are big enough.
        ///
        /// - Parameter dataset: The genotypes, with strata.
        public init(dataset: ImportedDataset) {
            var counts: [String: Int] = [:]
            for ordinal in 0..<dataset.matrix.individualCount {
                let name = dataset.populationName(at: ordinal)
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

    /// Estimates a population graph from the eligible populations.
    ///
    /// Nodes are placed at their population's centroid, when it has coordinates.
    ///
    /// - Parameter dataset: The genotypes, with strata and coordinates.
    /// - Returns: The graph, stamped with the dataset's fingerprint, or `nil` if
    ///   there are too few eligible populations or the decomposition fails.
    public static func estimate(from dataset: ImportedDataset) -> PopulationGraphDataset? {
        let eligibility = Eligibility(dataset: dataset)
        guard eligibility.canEstimate else { return nil }
        let names = Set(eligibility.included.map(\.name))
        let rows = (0..<dataset.matrix.individualCount).filter { names.contains(dataset.populationName(at: $0)) }
        let multivariate = dataset.matrix.multivariateMatrix()
        let x = multivariate.submatrix(rows, Array(0..<multivariate.cols))
        let groups = rows.map { dataset.populationName(at: $0) }
        guard let graph = PopulationGraph(x: x, groups: groups) else { return nil }

        let centroids = Dictionary(uniqueKeysWithValues: PopulationClusters(dataset: dataset).clusters
            .map { ($0.name, $0.centroid) })
        var lineages: [String: [StratumReference]] = [:]
        for lineage in dataset.strata.values {
            if let name = lineage.last?.name, lineages[name] == nil { lineages[name] = lineage }
        }
        var nodeStrata: [UUID: [StratumReference]] = [:]
        for node in graph.nodes {
            node.coordinate = centroids[node.name]
            nodeStrata[node.id] = lineages[node.name]
        }
        return PopulationGraphDataset(graph: graph, nodeStrata: nodeStrata,
                                      graphValues: [fingerprintKey: fingerprint(of: dataset)],
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
        return stamped != fingerprint(of: dataset)
    }

    /// A stable FNV-1a hash of every individual's population and genotypes,
    /// truncated to 53 bits so it survives storage as a `Double`.
    ///
    /// - Parameter dataset: The genotypes, with strata.
    /// - Returns: The fingerprint.
    public static func fingerprint(of dataset: ImportedDataset) -> Double {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        func mix(_ text: String) {
            for byte in text.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3 }
            hash = (hash ^ 0xff) &* 0x100_0000_01b3
        }
        for ordinal in 0..<dataset.matrix.individualCount {
            mix(dataset.populationName(at: ordinal))
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
}
