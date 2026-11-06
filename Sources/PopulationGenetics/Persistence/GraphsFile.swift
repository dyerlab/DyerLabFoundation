//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GraphsFile.swift
//  PopulationGenetics
//
//  The `.graphs` format: a `ProjectStore` file for one population graph and what
//  was derived from it, with no genotypes. It is the same SQLite schema as a
//  full project, so nothing here is a separate format; this just fixes which
//  components it has and how an app reads and saves one without disturbing them.
//
//  `ProjectStore` creates journal files beside its database, which the sandbox
//  forbids next to a user-chosen file, so all work happens on a private copy.
//
//  Created by Rodney Dyer on 2026.11.05.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Reads and saves `.graphs` files, which hold one population graph.
public enum GraphsFile {

    /// The file name extension.
    public static let fileExtension = "graphs"

    /// The uniform type identifier apps should declare for this format.
    public static let typeIdentifier = "com.dyerlab.graphs"

    /// The components of a new file. They are all created up front because a
    /// file can't gain a component later.
    public static let components: StoreComponents = [.graph, .results, .log, .matrices, .rasters]

    /// Reads a file's graph without decoding its other components.
    ///
    /// - Parameter url: The file to read.
    /// - Returns: The graph, the project's name and the graph's locus references.
    /// - Throws: ``GraphsFileError/noGraph`` if the file holds no graph, a ``PersistenceError``
    ///   if it isn't a readable store, or a file error if it can't be copied.
    public static func read(from url: URL) async throws -> GraphsFileContents {
        try await withScratchDirectory(near: nil) { directory in
            let working = directory.appendingPathComponent("working.\(fileExtension)")
            try FileManager.default.copyItem(at: url, to: working)
            let store = ProjectStore()
            try await store.open(at: working, mode: .readOnly)
            do {
                guard await store.presentComponents.contains(.graph) else { throw GraphsFileError.noGraph }
                let graph = try await store.readGraph()
                guard !graph.graph.nodes.isEmpty else { throw GraphsFileError.noGraph }
                let contents = GraphsFileContents(
                    projectName: try await store.metadata(forKey: ProjectStore.MetadataKey.projectName) ?? "",
                    graph: graph,
                    locusReferences: try await store.graphLocusReferences())
                await store.close()
                return contents
            } catch {
                await store.close()
                throw error
            }
        }
    }

    /// Writes a new file holding `contents`, replacing anything at `destination`.
    ///
    /// - Parameters:
    ///   - contents: The graph to store.
    ///   - destination: Where to write the file.
    /// - Throws: A ``PersistenceError`` or file error; `destination` is then unchanged.
    public static func create(_ contents: GraphsFileContents, at destination: URL) async throws {
        try await withScratchDirectory(near: destination) { directory in
            let working = directory.appendingPathComponent("working.\(fileExtension)")
            let store = ProjectStore()
            try await store.create(at: working, components: components, projectName: contents.projectName)
            do {
                let graph = contents.graph
                try await store.writeGraph(graph.graph, nodeStrata: graph.nodeStrata, nodeValues: graph.nodeValues,
                                           edgeValues: graph.edgeValues, graphValues: graph.graphValues)
                try await store.setGraphLocusReferences(contents.locusReferences)
                await store.close()
            } catch {
                await store.close()
                throw error
            }
            try install(working, at: destination)
        }
    }

    /// Encodes `contents` as the bytes of a new file, for handing to a save dialog.
    ///
    /// - Parameter contents: The graph to store.
    /// - Returns: The file's contents.
    /// - Throws: A ``PersistenceError`` or file error.
    public static func data(for contents: GraphsFileContents) async throws -> Data {
        try await withScratchDirectory(near: nil) { directory in
            let file = directory.appendingPathComponent("export.\(fileExtension)")
            try await create(contents, at: file)
            return try Data(contentsOf: file)
        }
    }

    /// Saves changed node attributes starting from the file as it is on disk
    /// now, so every other component, and anything another program changed since
    /// the file was opened, is kept.
    ///
    /// - Parameters:
    ///   - source: The existing file.
    ///   - update: The attributes to replace.
    ///   - destination: Where to write the result, which may be `source`.
    /// - Throws: ``GraphsFileError/nodesChanged`` if the file's nodes no longer match the update,
    ///   ``GraphsFileError/noGraph`` if it holds no graph, or a ``PersistenceError`` or file error.
    ///   `destination` is unchanged whenever this throws.
    public static func update(_ source: URL, applying update: GraphNodeAttributeUpdate,
                              to destination: URL) async throws {
        try await withScratchDirectory(near: destination) { directory in
            let working = directory.appendingPathComponent("working.\(fileExtension)")
            try FileManager.default.copyItem(at: source, to: working)
            let store = ProjectStore()
            try await store.open(at: working)
            do {
                guard await store.presentComponents.contains(.graph) else { throw GraphsFileError.noGraph }
                let graph = try update.applied(to: try await store.readGraph())
                try await store.writeGraph(graph.graph, nodeStrata: graph.nodeStrata, nodeValues: graph.nodeValues,
                                           edgeValues: graph.edgeValues, graphValues: graph.graphValues,
                                           loci: graph.loci)
                await store.close()
            } catch {
                await store.close()
                throw error
            }
            try install(working, at: destination)
        }
    }

    /// Puts a finished file in place, atomically when one is already there.
    private static func install(_ working: URL, at destination: URL) throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: working)
        } else {
            try FileManager.default.moveItem(at: working, to: destination)
        }
    }

    /// Runs `body` with a fresh private directory, deleted afterwards. When a
    /// destination is given, the directory is on its volume if possible, so the
    /// finished file can be swapped in rather than copied.
    private static func withScratchDirectory<T>(near destination: URL?,
                                                _ body: (URL) async throws -> T) async throws -> T {
        let fileManager = FileManager.default
        let base = destination.flatMap {
            try? fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: $0, create: true)
        } ?? fileManager.temporaryDirectory
        let directory = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: directory)
            if destination != nil, base != fileManager.temporaryDirectory { try? fileManager.removeItem(at: base) }
        }
        return try await body(directory)
    }
}
