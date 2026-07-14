//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeMatrixStore+GraphDecoding.swift
//  PopulationGenetics
//
//  The read path: reconstructs a `Graph` plus its
//  population-genetics metadata from the rows written by
//  `GenotypeMatrixStore+GraphEncoding`.
//
//  `Edge`'s initializer is internal to the Graph module, so edges can only be
//  reconstructed via `Graph.addEdge(from:to:weight:symmetric:)` — never by
//  constructing `Edge` directly. Each call appends exactly one edge when
//  `symmetric: false`, so `graph.edges.last` after each call is always the
//  edge just added, regardless of node/edge naming collisions.
//

import CoreLocation
import Foundation
import Graph
import SwiftUI

extension GenotypeMatrixStore {

    func decodeGraph(connection: SQLiteConnection) throws -> PopulationGraphDataset {
        let nodeRows = try readNodeRows(connection: connection)
        let graph = Graph()
        var nodesByOrdinal: [Int: Node] = [:]
        for row in nodeRows {
            graph.addNode(name: row.name, size: row.size, color: .gray)
            guard let node = graph.nodes.last else {
                throw PersistenceError.corruptData("failed to reconstruct node \"\(row.name)\"")
            }
            node.id = row.uuid
            if let latitude = row.latitude, let longitude = row.longitude {
                node.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }
            nodesByOrdinal[row.ordinal] = node
        }

        let edgeRows = try readEdgeRows(connection: connection)
        for row in edgeRows {
            guard let from = nodesByOrdinal[row.fromOrdinal], let to = nodesByOrdinal[row.toOrdinal] else {
                throw PersistenceError.corruptData("edge references a node ordinal not present in this graph")
            }
            graph.addEdge(from: from, to: to, weight: row.weight, symmetric: false)
            guard let edge = graph.edges.last else {
                throw PersistenceError.corruptData("failed to reconstruct edge")
            }
            edge.id = row.uuid
        }

        let nodeIDsByOrdinal = nodesByOrdinal.mapValues(\.id)
        let edgeIDsByOrdinal = Dictionary(uniqueKeysWithValues: graph.edges.enumerated().map { ($0, $1.id) })

        let nodeStrata = try readNodeStrata(nodesByOrdinal: nodesByOrdinal, connection: connection)
        let nodeValues = try readValues(table: "node_values", ordinalColumn: "node_ordinal",
                                         idsByOrdinal: nodeIDsByOrdinal, connection: connection)
        let edgeValues = try readValues(table: "edge_values", ordinalColumn: "edge_ordinal",
                                         idsByOrdinal: edgeIDsByOrdinal, connection: connection)
        let graphValues = try readGraphValues(connection: connection)
        let loci = try readGraphLoci(connection: connection)

        return PopulationGraphDataset(graph: graph, nodeStrata: nodeStrata, nodeValues: nodeValues,
                                       edgeValues: edgeValues, graphValues: graphValues, loci: loci)
    }

    // MARK: - Row readers

    private struct NodeRow {
        let ordinal: Int
        let uuid: UUID
        let name: String
        let size: Double
        let latitude: Double?
        let longitude: Double?
    }

    private struct EdgeRow {
        let uuid: UUID
        let fromOrdinal: Int
        let toOrdinal: Int
        let weight: Double
    }

    private func readNodeRows(connection: SQLiteConnection) throws -> [NodeRow] {
        let stmt = try connection.prepare("""
            SELECT ordinal, uuid, name, size, latitude, longitude FROM nodes ORDER BY ordinal
            """)
        var result: [NodeRow] = []
        while try stmt.step() {
            let uuidString = stmt.columnText(at: 1)
            guard let uuid = UUID(uuidString: uuidString) else {
                throw PersistenceError.corruptData("invalid node uuid: \(uuidString)")
            }
            result.append(NodeRow(ordinal: stmt.columnInt(at: 0), uuid: uuid, name: stmt.columnText(at: 2),
                                   size: stmt.columnDouble(at: 3), latitude: stmt.columnOptionalDouble(at: 4),
                                   longitude: stmt.columnOptionalDouble(at: 5)))
        }
        return result
    }

    private func readEdgeRows(connection: SQLiteConnection) throws -> [EdgeRow] {
        let stmt = try connection.prepare("""
            SELECT uuid, from_ordinal, to_ordinal, weight FROM edges ORDER BY ordinal
            """)
        var result: [EdgeRow] = []
        while try stmt.step() {
            let uuidString = stmt.columnText(at: 0)
            guard let uuid = UUID(uuidString: uuidString) else {
                throw PersistenceError.corruptData("invalid edge uuid: \(uuidString)")
            }
            result.append(EdgeRow(uuid: uuid, fromOrdinal: stmt.columnInt(at: 1),
                                   toOrdinal: stmt.columnInt(at: 2), weight: stmt.columnDouble(at: 3)))
        }
        return result
    }

    private func readNodeStrata(nodesByOrdinal: [Int: Node],
                                 connection: SQLiteConnection) throws -> [UUID: [StratumReference]] {
        let stmt = try connection.prepare("""
            SELECT node_ordinal, level, stratum_uuid, stratum_name FROM node_strata
            """)
        var result: [UUID: [StratumReference]] = [:]
        while try stmt.step() {
            let ordinal = stmt.columnInt(at: 0)
            guard let node = nodesByOrdinal[ordinal] else {
                throw PersistenceError.corruptData("node_strata references unknown node ordinal \(ordinal)")
            }
            let level = stmt.columnText(at: 1)
            let uuidString = stmt.columnText(at: 2)
            guard let uuid = UUID(uuidString: uuidString) else {
                throw PersistenceError.corruptData("invalid stratum uuid: \(uuidString)")
            }
            let name = stmt.columnText(at: 3)
            result[node.id, default: []].append(StratumReference(id: uuid, level: level, name: name))
        }
        return result
    }

    /// Shared codec for `node_values` and `edge_values`.
    private func readValues(table: String, ordinalColumn: String, idsByOrdinal: [Int: UUID],
                             connection: SQLiteConnection) throws -> [UUID: [GraphValue]] {
        let stmt = try connection.prepare("SELECT \(ordinalColumn), name, value, kind FROM \(table)")
        var result: [UUID: [GraphValue]] = [:]
        while try stmt.step() {
            let ordinal = stmt.columnInt(at: 0)
            guard let id = idsByOrdinal[ordinal] else {
                throw PersistenceError.corruptData("\(table) references unknown ordinal \(ordinal)")
            }
            let name = stmt.columnText(at: 1)
            let value = stmt.columnDouble(at: 2)
            let kindString = stmt.columnText(at: 3)
            guard let kind = GraphValue.Kind(rawValue: kindString) else {
                throw PersistenceError.corruptData("invalid kind in \(table): \(kindString)")
            }
            result[id, default: []].append(GraphValue(name: name, value: value, kind: kind))
        }
        return result
    }

    private func readGraphValues(connection: SQLiteConnection) throws -> [String: Double] {
        let stmt = try connection.prepare("SELECT name, value FROM graph_values")
        var result: [String: Double] = [:]
        while try stmt.step() {
            result[stmt.columnText(at: 0)] = stmt.columnDouble(at: 1)
        }
        return result
    }

    private func readGraphLoci(connection: SQLiteConnection) throws -> [Locus] {
        let stmt = try connection.prepare("""
            SELECT loci.uuid, loci.name, loci.contig, loci.location, loci.allele_provenance
            FROM graph_loci JOIN loci ON graph_loci.locus_ordinal = loci.ordinal
            ORDER BY loci.ordinal
            """)
        var result: [Locus] = []
        while try stmt.step() {
            let uuidString = stmt.columnText(at: 0)
            guard let uuid = UUID(uuidString: uuidString) else {
                throw PersistenceError.corruptData("invalid locus uuid: \(uuidString)")
            }
            let provenanceString = stmt.columnText(at: 4)
            guard let provenance = Locus.AlleleProvenance(rawValue: provenanceString) else {
                throw PersistenceError.corruptData("invalid allele_provenance: \(provenanceString)")
            }
            var locus = Locus(name: stmt.columnText(at: 1), location: UInt(stmt.columnInt(at: 3)),
                               contig: stmt.columnText(at: 2), alleleProvenance: provenance)
            locus.id = uuid
            result.append(locus)
        }
        return result
    }
}
