//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopulationGraphDataset.swift
//  PopulationGenetics
//
//  The full result of reading a population graph back out of a
//  `ProjectStore`: the `Graph` itself plus the
//  population-genetics metadata layered on top of it (stratum lineage,
//  numeric node/edge/graph measures, and which loci built it).
//
//  Created by Rodney Dyer on 2026.07.14.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Graph

/// The full contents of a persisted population graph, keyed by the
/// underlying graph's own `Node.id`/`Edge.id` values.
///
/// The graph itself is held as a `GraphSnapshot` (a `Sendable` value copy) so the
/// dataset can cross the `ProjectStore` actor boundary. Call ``makeGraph()`` to get
/// a live `Graph` for analysis or layout.
public struct PopulationGraphDataset: Sendable {

    /// The graph's nodes and edges (nodes carry `name`, `size`, `coordinate`).
    public let graph: GraphSnapshot

    /// Ancestor stratum lineage per node, keyed by `Node.id`.
    public let nodeStrata: [UUID: [StratumReference]]

    /// Sparse numeric measures per node, keyed by `Node.id`.
    public let nodeValues: [UUID: [GraphValue]]

    /// Sparse numeric measures per edge, keyed by `Edge.id`.
    public let edgeValues: [UUID: [GraphValue]]

    /// Graph-wide computed measures (diameter, component count, ...) by name.
    public let graphValues: [String: Double]

    /// The loci (from this same file's genotype data) that this graph was
    /// built from. Provenance only — no genotype calls are duplicated here.
    public let loci: [Locus]

    /// Initializes a new population graph dataset.
    ///
    /// - Parameters:
    ///   - graph: The graph's nodes and edges (nodes carry `name`, `size`, `coordinate`).
    ///   - nodeStrata: Ancestor stratum lineage per node, keyed by `Node.id`.
    ///   - nodeValues: Sparse numeric measures per node, keyed by `Node.id`.
    ///   - edgeValues: Sparse numeric measures per edge, keyed by `Edge.id`.
    ///   - graphValues: Graph-wide computed measures (diameter, component count, ...) by name.
    ///   - loci: The loci (from this same file's genotype data) that this graph was built from.
    public init(graph: GraphSnapshot, nodeStrata: [UUID: [StratumReference]] = [:],
                nodeValues: [UUID: [GraphValue]] = [:], edgeValues: [UUID: [GraphValue]] = [:],
                graphValues: [String: Double] = [:], loci: [Locus] = []) {
        self.graph = graph
        self.nodeStrata = nodeStrata
        self.nodeValues = nodeValues
        self.edgeValues = edgeValues
        self.graphValues = graphValues
        self.loci = loci
    }

    /// Initializes a new population graph dataset from a live graph, capturing its
    /// current nodes and edges.
    ///
    /// - Parameters:
    ///   - graph: The graph to capture.
    ///   - nodeStrata: Ancestor stratum lineage per node, keyed by `Node.id`.
    ///   - nodeValues: Sparse numeric measures per node, keyed by `Node.id`.
    ///   - edgeValues: Sparse numeric measures per edge, keyed by `Edge.id`.
    ///   - graphValues: Graph-wide computed measures (diameter, component count, ...) by name.
    ///   - loci: The loci (from this same file's genotype data) that this graph was built from.
    public init(graph: Graph, nodeStrata: [UUID: [StratumReference]] = [:],
                nodeValues: [UUID: [GraphValue]] = [:], edgeValues: [UUID: [GraphValue]] = [:],
                graphValues: [String: Double] = [:], loci: [Locus] = []) {
        self.init(graph: GraphSnapshot(graph), nodeStrata: nodeStrata, nodeValues: nodeValues,
                  edgeValues: edgeValues, graphValues: graphValues, loci: loci)
    }

    /// Builds a new live `Graph` from ``graph``, with the original node and edge identifiers.
    ///
    /// - Returns: A fresh graph; each call returns a new instance.
    public func makeGraph() -> Graph {
        graph.makeGraph()
    }
}
