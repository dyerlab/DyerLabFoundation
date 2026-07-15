//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeMatrixStore.swift
//  PopulationGenetics
//
//  A SQLite-backed store for `GenotypeMatrix`. An actor, so a downstream
//  document (`NSDocument`/`UIDocument`) can hold one and `await` its methods
//  from any context without hand-rolled locking; this package stays
//  platform-neutral and does not import AppKit/UIKit itself.
//

import Foundation
import Graph

/// A SQLite-backed store for a `GenotypeMatrix` and its associated population graph.
///
/// An actor, so a downstream document (`NSDocument`/`UIDocument`) can hold one and
/// `await` its methods from any context without hand-rolled locking; this package
/// stays platform-neutral and does not import AppKit/UIKit itself.
public actor GenotypeMatrixStore {

    /// Whether a connection was opened for reading only or for reading and writing.
    public enum OpenMode: Sendable {
        /// The connection permits reads but rejects writes.
        case readOnly
        /// The connection permits both reads and writes.
        case readWrite
    }

    private var connection: SQLiteConnection?
    var mode: OpenMode = .readWrite

    /// Creates a store with no open connection. Call `create(at:overwrite:)` or
    /// `open(at:mode:)` before using it.
    public init() {}

    /// Creates a brand-new SQLite file with the schema installed.
    ///
    /// - Parameters:
    ///   - url: Destination file URL.
    ///   - overwrite: When `true`, removes any existing file at `url` first. When
    ///     `false` (default), throws `.cannotOpen` if a file already exists there.
    public func create(at url: URL, overwrite: Bool = false) async throws {
        if overwrite {
            try? FileManager.default.removeItem(at: url)
        } else if FileManager.default.fileExists(atPath: url.path) {
            throw PersistenceError.cannotOpen("file already exists at \(url.path)")
        }
        let newConnection = SQLiteConnection()
        try newConnection.open(at: url, mode: .readWriteCreate)
        try GenotypeMatrixSQLiteSchema.createSchema(in: newConnection)
        try PopulationGraphSQLiteSchema.createSchema(in: newConnection)
        connection = newConnection
        mode = .readWrite
    }

    /// Opens an existing SQLite file, validating its schema versions first.
    public func open(at url: URL, mode: OpenMode = .readWrite) async throws {
        let newConnection = SQLiteConnection()
        try newConnection.open(at: url, mode: mode == .readOnly ? .readOnly : .readWrite)
        try GenotypeMatrixSQLiteSchema.validateSchemaVersion(of: newConnection)
        try PopulationGraphSQLiteSchema.validateSchemaVersion(of: newConnection)
        connection = newConnection
        self.mode = mode
    }

    /// Closes the connection, checkpointing the WAL first so the file left on
    /// disk is self-contained. Safe to call multiple times or when not open.
    public func close() async {
        if let connection {
            try? connection.checkpointAndTruncateWAL()
            connection.close()
        }
        connection = nil
    }

    func requireConnection() throws -> SQLiteConnection {
        guard let connection else { throw PersistenceError.notOpen }
        return connection
    }

    /// Writes the full dataset into the currently open connection in one transaction,
    /// replacing any existing rows.
    public func write(matrix: GenotypeMatrix, parentage: ParentageDesign? = nil,
                       strata: [UUID: [StratumReference]] = [:],
                       projectName: String, species: String? = nil) async throws {
        guard mode == .readWrite else { throw PersistenceError.readOnly }
        let connection = try requireConnection()
        try connection.beginTransaction()
        do {
            try writeMeta(matrix: matrix, parentage: parentage, projectName: projectName, species: species,
                          connection: connection)
            try writeIndividuals(matrix.individuals, connection: connection)
            try writeIndividualStrata(strata, individuals: matrix.individuals, connection: connection)
            try writeLoci(matrix: matrix, connection: connection)
            try writeCodebooksAndBlobs(matrix: matrix, connection: connection)
            try writeParentage(parentage, connection: connection)
            try connection.commit()
        } catch {
            try? connection.rollback()
            throw error
        }
    }

    /// Reconstructs the `GenotypeMatrix` from the currently open connection.
    public func readMatrix() async throws -> GenotypeMatrix {
        try decodeMatrix(connection: try requireConnection())
    }

    /// Reconstructs the `ParentageDesign`, or `nil` if no families were stored.
    public func readParentage() async throws -> ParentageDesign? {
        try decodeParentage(connection: try requireConnection())
    }

    /// Reconstructs each individual's hierarchical stratum lineage, keyed by
    /// `Individual.id`. Empty if no strata were stored.
    public func readIndividualStrata() async throws -> [UUID: [StratumReference]] {
        try readIndividualStrata(connection: try requireConnection())
    }

    /// Reconstructs the full `ImportedDataset`, synthesizing an empty
    /// `ParentageDesign` when none was stored.
    public func readDataset() async throws -> ImportedDataset {
        let connection = try requireConnection()
        let matrix = try decodeMatrix(connection: connection)
        let parentage = try decodeParentage(connection: connection) ?? ParentageDesign(families: [])
        let strata = try readIndividualStrata(connection: connection)
        return ImportedDataset(matrix: matrix, parentage: parentage, strata: strata)
    }

    /// Writes the population graph into the currently open connection, in one
    /// transaction. A file holds at most one graph; call at most once per file.
    ///
    /// - Parameters:
    ///   - graph: The graph structure itself (nodes carry `name`, `size`, `coordinate`).
    ///   - nodeStrata: Ancestor stratum lineage per node, keyed by `Node.id`.
    ///   - nodeValues: Sparse numeric measures per node, keyed by `Node.id`.
    ///   - edgeValues: Sparse numeric measures per edge, keyed by `Edge.id`.
    ///   - graphValues: Graph-wide computed measures (diameter, component count, ...) by name.
    ///   - loci: The loci this graph was built from. Every locus here must already be
    ///     present in this file's `loci` table (i.e. written via `write(matrix:...)` first).
    public func writeGraph(_ graph: Graph, nodeStrata: [UUID: [StratumReference]] = [:],
                            nodeValues: [UUID: [GraphValue]] = [:], edgeValues: [UUID: [GraphValue]] = [:],
                            graphValues: [String: Double] = [:], loci: [Locus] = []) async throws {
        guard mode == .readWrite else { throw PersistenceError.readOnly }
        let connection = try requireConnection()
        try connection.beginTransaction()
        do {
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
            try setMetaFlag("has_graph", to: true, connection: connection)
            try connection.commit()
        } catch {
            try? connection.rollback()
            throw error
        }
    }

    /// Reconstructs the population graph and its associated metadata from the
    /// currently open connection.
    public func readGraph() async throws -> PopulationGraphDataset {
        try decodeGraph(connection: try requireConnection())
    }

    /// One-shot convenience: creates (overwriting) a new file and writes `matrix` to it.
    public static func save(_ matrix: GenotypeMatrix, parentage: ParentageDesign? = nil,
                             strata: [UUID: [StratumReference]] = [:],
                             projectName: String, species: String? = nil, to url: URL) async throws {
        let store = GenotypeMatrixStore()
        try await store.create(at: url, overwrite: true)
        try await store.write(matrix: matrix, parentage: parentage, strata: strata,
                               projectName: projectName, species: species)
        await store.close()
    }

    /// One-shot convenience: opens `url` read-only and returns the full dataset.
    public static func load(from url: URL) async throws -> ImportedDataset {
        let store = GenotypeMatrixStore()
        try await store.open(at: url, mode: .readOnly)
        let dataset = try await store.readDataset()
        await store.close()
        return dataset
    }
}
