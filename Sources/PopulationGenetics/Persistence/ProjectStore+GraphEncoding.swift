//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ProjectStore+GraphEncoding.swift
//  PopulationGenetics
//
//  Read/write access to the `.graph` component: turns an in-memory `Graph`
//  plus its population-genetics metadata into rows in the schema defined by
//  `GraphSchemaComponent.swift`.
//
//  Created by Rodney Dyer on 2026.07.14.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Graph

extension ProjectStore {

    /// Writes a live graph, capturing it as a `GraphSnapshot` on the caller's actor
    /// first so the non-`Sendable` `Graph` never crosses into this actor.
    ///
    /// - Parameters:
    ///   - graph: The graph structure itself (nodes carry `name`, `size`, `coordinate`).
    ///   - nodeStrata: Ancestor stratum lineage per node, keyed by `Node.id`.
    ///   - nodeValues: Sparse numeric measures per node, keyed by `Node.id`.
    ///   - edgeValues: Sparse numeric measures per edge, keyed by `Edge.id`.
    ///   - graphValues: Graph-wide computed measures (diameter, component count, ...) by name.
    ///   - loci: The loci this graph was built from, if any (see the snapshot overload).
    /// - Throws: The same errors as the `GraphSnapshot` overload.
    nonisolated public func writeGraph(_ graph: Graph, nodeStrata: [UUID: [StratumReference]] = [:],
                                       nodeValues: [UUID: [GraphValue]] = [:], edgeValues: [UUID: [GraphValue]] = [:],
                                       graphValues: [String: Double] = [:], loci: [Locus] = []) async throws {
        try await writeGraph(GraphSnapshot(graph), nodeStrata: nodeStrata, nodeValues: nodeValues,
                             edgeValues: edgeValues, graphValues: graphValues, loci: loci)
    }

    /// Writes the population graph into the currently open connection, in one
    /// transaction, replacing any previously-written graph. Leaves every
    /// other component (geneticData/results/log/matrices) untouched.
    ///
    /// - Parameters:
    ///   - graph: The graph's nodes and edges (nodes carry `name`, `size`, `coordinate`).
    ///   - nodeStrata: Ancestor stratum lineage per node, keyed by `Node.id`.
    ///   - nodeValues: Sparse numeric measures per node, keyed by `Node.id`.
    ///   - edgeValues: Sparse numeric measures per edge, keyed by `Edge.id`.
    ///   - graphValues: Graph-wide computed measures (diameter, component count, ...) by name.
    ///   - loci: The loci this graph was built from, if any. Every locus here must
    ///     already be present in this file's `loci` table (i.e. `.geneticData` written
    ///     first via `writeGeneticData`) — leave empty for a graph with no underlying
    ///     genetic data.
    /// - Throws: ``PersistenceError/readOnly`` for a read-only store, ``PersistenceError/componentNotPresent(_:)``
    ///   without a `.graph` component, ``PersistenceError/notOpen``, ``PersistenceError/corruptData(_:)`` if an
    ///   edge, stratum or value references an unknown node or edge, or a locus isn't in the `loci` table, or
    ///   ``PersistenceError/sqliteError(code:message:)`` if a write fails.
    public func writeGraph(_ graph: GraphSnapshot, nodeStrata: [UUID: [StratumReference]] = [:],
                            nodeValues: [UUID: [GraphValue]] = [:], edgeValues: [UUID: [GraphValue]] = [:],
                            graphValues: [String: Double] = [:], loci: [Locus] = []) async throws {
        guard mode == .readWrite else { throw PersistenceError.readOnly }
        try requireComponent(.graph, "graph")
        let connection = try requireConnection()
        try connection.beginTransaction()
        do {
            try deleteGraphRows(connection: connection)
            let nodeOrdinals = try writeNodes(graph.nodes, connection: connection)
            try writeEdges(graph.edges, nodeOrdinals: nodeOrdinals, connection: connection)
            try writeNodeStrata(nodeStrata, nodeOrdinals: nodeOrdinals, connection: connection)
            try writeValues(table: "node_values", ordinalColumn: "node_ordinal",
                             values: nodeValues, ordinals: nodeOrdinals, connection: connection)
            let edgeOrdinals = Dictionary(uniqueKeysWithValues: graph.edges.enumerated().map { ($1.id, $0) })
            try writeValues(table: "edge_values", ordinalColumn: "edge_ordinal",
                             values: edgeValues, ordinals: edgeOrdinals, connection: connection)
            try writeGraphValues(graphValues, connection: connection)
            try writeGraphLoci(loci, connection: connection)
            try setMetaFlag(GraphSchemaComponent.hasFlagKey, to: true, connection: connection)
            try connection.commit()
        } catch {
            try? connection.rollback()
            throw error
        }
    }

    // MARK: - Write helpers

    /// Clears every row this component owns, so `writeGraph` can be called
    /// again on an already-populated connection to replace the graph.
    private func deleteGraphRows(connection: SQLiteConnection) throws {
        for table in ["graph_loci", "graph_values", "edge_values", "edges", "node_values", "node_strata", "nodes"] {
            try connection.execute("DELETE FROM \(table)")
        }
    }

    /// Writes `nodes`, returning each node's assigned ordinal keyed by its `id`
    /// so later tables (edges, node_strata, node_values) can reference it.
    ///
    /// - Parameters:
    ///   - nodes: The nodes to insert, in order.
    ///   - connection: The open connection to write to.
    /// - Returns: Each node's ordinal keyed by its `id`.
    /// - Throws: ``PersistenceError/sqliteError(code:message:)`` if an insert fails.
    func writeNodes(_ nodes: [GraphSnapshot.NodeRecord], connection: SQLiteConnection) throws -> [UUID: Int] {
        let stmt = try connection.prepare("""
            INSERT INTO nodes (ordinal, uuid, name, size, latitude, longitude) VALUES (?, ?, ?, ?, ?, ?)
            """)
        var ordinals: [UUID: Int] = [:]
        for (ordinal, node) in nodes.enumerated() {
            stmt.reset()
            stmt.bind(ordinal, at: 1)
            stmt.bind(node.id.uuidString, at: 2)
            stmt.bind(node.name, at: 3)
            stmt.bind(node.size, at: 4)
            stmt.bindOptional(node.latitude, at: 5)
            stmt.bindOptional(node.longitude, at: 6)
            _ = try stmt.step()
            ordinals[node.id] = ordinal
        }
        return ordinals
    }

    func writeEdges(_ edges: [GraphSnapshot.EdgeRecord], nodeOrdinals: [UUID: Int],
                    connection: SQLiteConnection) throws {
        let stmt = try connection.prepare("""
            INSERT INTO edges (ordinal, uuid, from_ordinal, to_ordinal, weight) VALUES (?, ?, ?, ?, ?)
            """)
        for (ordinal, edge) in edges.enumerated() {
            guard let fromOrdinal = nodeOrdinals[edge.fromNode], let toOrdinal = nodeOrdinals[edge.toNode] else {
                throw PersistenceError.corruptData("edge \(edge.id) references a node not present in this graph")
            }
            stmt.reset()
            stmt.bind(ordinal, at: 1)
            stmt.bind(edge.id.uuidString, at: 2)
            stmt.bind(fromOrdinal, at: 3)
            stmt.bind(toOrdinal, at: 4)
            stmt.bind(edge.weight, at: 5)
            _ = try stmt.step()
        }
    }

    func writeNodeStrata(_ nodeStrata: [UUID: [StratumReference]], nodeOrdinals: [UUID: Int],
                          connection: SQLiteConnection) throws {
        guard !nodeStrata.isEmpty else { return }
        let stmt = try connection.prepare("""
            INSERT INTO node_strata (node_ordinal, level, stratum_uuid, stratum_name) VALUES (?, ?, ?, ?)
            """)
        for (nodeID, references) in nodeStrata {
            guard let ordinal = nodeOrdinals[nodeID] else {
                throw PersistenceError.corruptData("node_strata references a node not present in this graph")
            }
            for reference in references {
                stmt.reset()
                stmt.bind(ordinal, at: 1)
                stmt.bind(reference.level, at: 2)
                stmt.bind(reference.id.uuidString, at: 3)
                stmt.bind(reference.name, at: 4)
                _ = try stmt.step()
            }
        }
    }

    /// Shared codec for `node_values` and `edge_values`, which share one
    /// `(ordinal, name, value, kind)` shape.
    ///
    /// - Parameters:
    ///   - table: `"node_values"` or `"edge_values"`.
    ///   - ordinalColumn: The table's owner-ordinal column.
    ///   - values: Values keyed by node or edge id.
    ///   - ordinals: Ordinals keyed by node or edge id.
    ///   - connection: The open connection to write to.
    /// - Throws: ``PersistenceError/corruptData(_:)`` if an id has no ordinal, or
    ///   ``PersistenceError/sqliteError(code:message:)`` if an insert fails.
    func writeValues(table: String, ordinalColumn: String, values: [UUID: [GraphValue]],
                      ordinals: [UUID: Int], connection: SQLiteConnection) throws {
        guard !values.isEmpty else { return }
        let stmt = try connection.prepare("""
            INSERT INTO \(table) (\(ordinalColumn), name, value, kind) VALUES (?, ?, ?, ?)
            """)
        for (id, items) in values {
            guard let ordinal = ordinals[id] else {
                throw PersistenceError.corruptData("\(table) references an id not present in this graph")
            }
            for item in items {
                stmt.reset()
                stmt.bind(ordinal, at: 1)
                stmt.bind(item.name, at: 2)
                stmt.bind(item.value, at: 3)
                stmt.bind(item.kind.rawValue, at: 4)
                _ = try stmt.step()
            }
        }
    }

    func writeGraphValues(_ values: [String: Double], connection: SQLiteConnection) throws {
        guard !values.isEmpty else { return }
        let stmt = try connection.prepare("INSERT INTO graph_values (name, value) VALUES (?, ?)")
        for (name, value) in values {
            stmt.reset()
            stmt.bind(name, at: 1)
            stmt.bind(value, at: 2)
            _ = try stmt.step()
        }
    }

    /// Records which of this file's already-written loci built the graph.
    /// Every locus must already exist in the `loci` table (written via
    /// `writeGeneticData`); this never duplicates locus metadata.
    ///
    /// - Parameters:
    ///   - loci: The loci the graph was built from.
    ///   - connection: The open connection to write to.
    /// - Throws: ``PersistenceError/corruptData(_:)`` if a locus isn't in the `loci` table, or
    ///   ``PersistenceError/sqliteError(code:message:)`` if a query fails.
    func writeGraphLoci(_ loci: [Locus], connection: SQLiteConnection) throws {
        guard !loci.isEmpty else { return }
        let lookupStmt = try connection.prepare("SELECT ordinal FROM loci WHERE uuid = ?")
        let insertStmt = try connection.prepare("INSERT INTO graph_loci (locus_ordinal) VALUES (?)")
        for locus in loci {
            lookupStmt.reset()
            lookupStmt.bind(locus.id.uuidString, at: 1)
            guard try lookupStmt.step() else {
                throw PersistenceError.corruptData(
                    "graph references locus \"\(locus.name)\" not present in this file's loci table")
            }
            let ordinal = lookupStmt.columnInt(at: 0)
            insertStmt.reset()
            insertStmt.bind(ordinal, at: 1)
            _ = try insertStmt.step()
        }
    }
}
