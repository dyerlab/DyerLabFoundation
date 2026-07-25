//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ProjectStore.swift
//  PopulationGenetics
//
//  A SQLite-backed store for a project's data: genetic data, a population
//  graph, results/images, a log, and generic named matrices — five equal,
//  independently optional components (`StoreComponents`). No component is
//  privileged; a file can hold any subset, including zero genetic data.
//
//  An actor, so a downstream document (`NSDocument`/`UIDocument`) can hold
//  one and `await` its methods from any context without hand-rolled locking;
//  this package stays platform-neutral and does not import AppKit/UIKit
//  itself. Hold one `ProjectStore` open across a document's session — via
//  `openOrCreate(at:)` — rather than reaching for `create(overwrite:true)`
//  on every save, which destroys the file and any component data a caller
//  isn't currently touching.
//

import Foundation
import Graph

/// A SQLite-backed store for a project's genetic data, population graph,
/// results/images, log, and generic named matrices.
public actor ProjectStore {

    /// Whether a connection was opened for reading only or for reading and writing.
    public enum OpenMode: Sendable {
        /// The connection permits reads but rejects writes.
        case readOnly
        /// The connection permits both reads and writes.
        case readWrite
    }

    private var connection: SQLiteConnection?
    var mode: OpenMode = .readWrite

    /// Which components are present in the currently open file. Computed
    /// once at `create`/`open` time; fixed for the lifetime of a connection.
    private(set) var presentComponents: StoreComponents = []

    /// Creates a store with no open connection. Call `create(at:overwrite:...)`,
    /// `open(at:mode:)`, or `openOrCreate(at:...)` before using it.
    public init() {}

    /// Creates a brand-new SQLite file with `meta` plus the requested
    /// components' schemas installed.
    ///
    /// - Parameters:
    ///   - url: Destination file URL.
    ///   - overwrite: When `true`, removes any existing file at `url` first. When
    ///     `false` (default), throws `.cannotOpen` if a file already exists there.
    ///   - components: Which data components to create. Defaults to `.all`.
    ///   - projectName: The project's name, written unconditionally regardless
    ///     of which components are included.
    ///   - species: Optional species this project concerns.
    ///   - description: Optional free-text description of the project.
    public func create(at url: URL, overwrite: Bool = false, components: StoreComponents = .all,
                        projectName: String, species: String? = nil, description: String? = nil) async throws {
        if overwrite {
            try? FileManager.default.removeItem(at: url)
        } else if FileManager.default.fileExists(atPath: url.path) {
            throw PersistenceError.cannotOpen("file already exists at \(url.path)")
        }
        let newConnection = SQLiteConnection()
        try newConnection.open(at: url, mode: .readWriteCreate)
        try newConnection.execute("""
            CREATE TABLE meta (
                key   TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
            """)
        try writeProjectMeta(projectName: projectName, species: species, description: description,
                              connection: newConnection)
        if components.contains(.geneticData) { try GeneticDataSchemaComponent.createSchema(in: newConnection) }
        if components.contains(.graph) { try GraphSchemaComponent.createSchema(in: newConnection) }
        if components.contains(.results) { try ResultsSchemaComponent.createSchema(in: newConnection) }
        if components.contains(.log) { try LogSchemaComponent.createSchema(in: newConnection) }
        if components.contains(.matrices) { try MatricesSchemaComponent.createSchema(in: newConnection) }
        connection = newConnection
        presentComponents = components
        mode = .readWrite
    }

    /// Opens an existing SQLite file, validating the schema version of
    /// whichever components are present.
    public func open(at url: URL, mode: OpenMode = .readWrite) async throws {
        let newConnection = SQLiteConnection()
        try newConnection.open(at: url, mode: mode == .readOnly ? .readOnly : .readWrite)
        var found: StoreComponents = []
        if try GeneticDataSchemaComponent.isPresent(in: newConnection) {
            try GeneticDataSchemaComponent.validateSchemaVersion(of: newConnection)
            found.insert(.geneticData)
        }
        if try GraphSchemaComponent.isPresent(in: newConnection) {
            try GraphSchemaComponent.validateSchemaVersion(of: newConnection)
            found.insert(.graph)
        }
        if try ResultsSchemaComponent.isPresent(in: newConnection) {
            try ResultsSchemaComponent.validateSchemaVersion(of: newConnection)
            found.insert(.results)
        }
        if try LogSchemaComponent.isPresent(in: newConnection) {
            try LogSchemaComponent.validateSchemaVersion(of: newConnection)
            found.insert(.log)
        }
        if try MatricesSchemaComponent.isPresent(in: newConnection) {
            try MatricesSchemaComponent.validateSchemaVersion(of: newConnection)
            found.insert(.matrices)
        }
        connection = newConnection
        presentComponents = found
        self.mode = mode
    }

    /// Opens `url` read-write if it already exists (component/project
    /// arguments are ignored in that case), or creates it otherwise.
    ///
    /// This is the entry point a long-lived document session should hold
    /// across its lifetime, instead of `create(overwrite:true)`, which
    /// destroys the file — and every component's data — on every save.
    ///
    /// - Throws: `.cannotOpen` if the file doesn't exist and `projectName` is `nil`.
    public func openOrCreate(at url: URL, components: StoreComponents = .all, projectName: String? = nil,
                              species: String? = nil, description: String? = nil) async throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try await open(at: url, mode: .readWrite)
        } else {
            guard let projectName else {
                throw PersistenceError.cannotOpen("projectName is required to create a new project at \(url.path)")
            }
            try await create(at: url, overwrite: false, components: components, projectName: projectName,
                              species: species, description: description)
        }
    }

    /// Closes the connection, checkpointing the WAL first so the file left on
    /// disk is self-contained. Safe to call multiple times or when not open.
    public func close() async {
        if let connection {
            try? connection.checkpointAndTruncateWAL()
            connection.close()
        }
        connection = nil
        presentComponents = []
    }

    func requireConnection() throws -> SQLiteConnection {
        guard let connection else { throw PersistenceError.notOpen }
        return connection
    }

    /// Throws `.componentNotPresent` unless `component` was created for this file.
    func requireComponent(_ component: StoreComponents, _ label: String) throws {
        guard presentComponents.contains(component) else {
            throw PersistenceError.componentNotPresent(label)
        }
    }

    private func writeProjectMeta(projectName: String, species: String?, description: String?,
                                   connection: SQLiteConnection) throws {
        let stmt = try connection.prepare("INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)")
        let rows: [(String, String)] = [
            ("project_name", projectName),
            ("species", species ?? ""),
            ("description", description ?? ""),
            ("created_at", ISO8601DateFormatter().string(from: Date())),
        ]
        for (key, value) in rows {
            stmt.reset()
            stmt.bind(key, at: 1)
            stmt.bind(value, at: 2)
            _ = try stmt.step()
        }
    }

    /// One-shot convenience: creates (overwriting) a new file with only the
    /// `.geneticData` component and writes `matrix` to it. Destructive —
    /// discards any existing graph/results/log/matrices at `url`. Intended
    /// for one-shot export or tests, not a document's save path; hold a
    /// store open via `openOrCreate(at:)` and call `writeGeneticData`/
    /// `writeGraph`/`addResult`/`appendLog`/`addMatrix` instead if the file
    /// may already carry other components.
    public static func save(_ matrix: GenotypeMatrix, parentage: ParentageDesign? = nil,
                             strata: [UUID: [StratumReference]] = [:],
                             projectName: String, species: String? = nil, description: String? = nil,
                             to url: URL) async throws {
        let store = ProjectStore()
        try await store.create(at: url, overwrite: true, components: .geneticData, projectName: projectName,
                                species: species, description: description)
        try await store.writeGeneticData(matrix: matrix, parentage: parentage, strata: strata)
        await store.close()
    }

    /// One-shot convenience: opens `url` read-only and returns the full genetic dataset.
    public static func load(from url: URL) async throws -> ImportedDataset {
        let store = ProjectStore()
        try await store.open(at: url, mode: .readOnly)
        let dataset = try await store.readDataset()
        await store.close()
        return dataset
    }
}
