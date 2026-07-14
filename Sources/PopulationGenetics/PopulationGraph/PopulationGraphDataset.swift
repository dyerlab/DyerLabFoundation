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
//  `GenotypeMatrixStore`: the `Graph` itself plus the
//  population-genetics metadata layered on top of it (stratum lineage,
//  numeric node/edge/graph measures, and which loci built it).
//

import Foundation
import Graph

/// `Graph`/`Node`/`Edge` (from the Graph module) are plain reference types with
/// no `Sendable` conformance of their own. Each read constructs a fresh
/// graph that the actor-isolated `GenotypeMatrixStore` hands off and never
/// touches again, so treating them as `Sendable` here is safe in practice
/// even though the compiler can't verify it structurally.
///
/// Not `@retroactive`: that attribute only applies to a conformance added
/// from outside the type's own module/package. `Graph`/`Node`/`Edge` and
/// this extension now live in the same Swift package (both are targets of
/// DyerLabFoundation), so Swift 6 rejects `@retroactive` here as
/// inapplicable — it was needed when PopulationGenetics consumed Graph as
/// an external SPM dependency, not now that it's a sibling target.
extension Graph: @unchecked Sendable {}
extension Node: @unchecked Sendable {}
extension Edge: @unchecked Sendable {}

/// The full contents of a persisted population graph, keyed by the
/// underlying `Graph`'s own `Node.id`/`Edge.id` values.
public struct PopulationGraphDataset: Sendable {

    /// The reconstructed graph (nodes carry `name`, `size`, `coordinate`).
    public let graph: Graph

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
    ///   - graph: The reconstructed graph (nodes carry `name`, `size`, `coordinate`).
    ///   - nodeStrata: Ancestor stratum lineage per node, keyed by `Node.id`.
    ///   - nodeValues: Sparse numeric measures per node, keyed by `Node.id`.
    ///   - edgeValues: Sparse numeric measures per edge, keyed by `Edge.id`.
    ///   - graphValues: Graph-wide computed measures (diameter, component count, ...) by name.
    ///   - loci: The loci (from this same file's genotype data) that this graph was built from.
    public init(graph: Graph, nodeStrata: [UUID: [StratumReference]] = [:],
                nodeValues: [UUID: [GraphValue]] = [:], edgeValues: [UUID: [GraphValue]] = [:],
                graphValues: [String: Double] = [:], loci: [Locus] = []) {
        self.graph = graph
        self.nodeStrata = nodeStrata
        self.nodeValues = nodeValues
        self.edgeValues = edgeValues
        self.graphValues = graphValues
        self.loci = loci
    }
}
