//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeMatrixStore+GraphEncoding.swift
//  PopulationGenetics
//
//  The write path: turns an in-memory `Graph` plus its
//  population-genetics metadata into rows in the schema defined by
//  `PopulationGraphSQLiteSchema`.
//

import Foundation
import Graph

extension GenotypeMatrixStore {

    /// Writes `nodes`, returning each node's assigned ordinal keyed by its `id`
    /// so later tables (edges, node_strata, node_values) can reference it.
    func writeNodes(_ nodes: [Node], connection: SQLiteConnection) throws -> [UUID: Int] {
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
            stmt.bindOptional(node.coordinate?.latitude, at: 5)
            stmt.bindOptional(node.coordinate?.longitude, at: 6)
            _ = try stmt.step()
            ordinals[node.id] = ordinal
        }
        return ordinals
    }

    func writeEdges(_ edges: [Edge], nodeOrdinals: [UUID: Int], connection: SQLiteConnection) throws {
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
    /// `write(matrix:...)`); this never duplicates locus metadata.
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
