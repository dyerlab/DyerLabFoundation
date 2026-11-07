//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ProjectFile.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.10.23.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Converts between a `ProjectSnapshot` and the bytes of a `.gstudio` file.
///
/// `ProjectStore` works on a SQLite file at a URL and creates temporary and
/// journal files beside it, which the sandbox forbids next to a user-chosen
/// file. So the store always lives in a private temporary directory, and only
/// the finished bytes cross over to the document's real location.
public enum ProjectFile {

    /// Encodes a project as the bytes of a `.gstudio` file.
    ///
    /// - Parameter snapshot: Every component of the project.
    /// - Returns: The file's contents.
    /// - Throws: `PersistenceError` if the project cannot be written, or a file
    ///   error if the scratch directory cannot be used.
    public static func data(for snapshot: ProjectSnapshot) async throws -> Data {
        try await withScratchFile { url in
            try await ProjectStore.saveSnapshot(dataset: snapshot.dataset,
                                                graph: snapshot.graph,
                                                results: snapshot.results,
                                                logEntries: snapshot.logEntries,
                                                matrices: snapshot.matrices,
                                                rasters: snapshot.rasters,
                                                figures: snapshot.figures,
                                                projectName: snapshot.projectName,
                                                species: snapshot.species,
                                                description: snapshot.description,
                                                metadata: snapshot.metadata,
                                                to: url)
            return try Data(contentsOf: url)
        }
    }

    /// Decodes the bytes of a `.gstudio` file.
    ///
    /// - Parameter data: The file's contents.
    /// - Returns: Every component of the project.
    /// - Throws: `PersistenceError` if `data` is not a readable project, or a
    ///   file error if the scratch directory cannot be used.
    public static func snapshot(from data: Data) async throws -> ProjectSnapshot {
        try await withScratchFile { url in
            try data.write(to: url)
            return try await ProjectStore.loadSnapshot(from: url)
        }
    }

    /// Runs `body` with a `.gstudio` path in a fresh temporary directory, which
    /// is deleted afterwards.
    ///
    /// - Parameter body: Works with the file at the given path.
    /// - Returns: What `body` returns.
    /// - Throws: A file error if the directory can't be created, or whatever `body` throws.
    private static func withScratchFile<T>(_ body: (URL) async throws -> T) async throws -> T {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        return try await body(directory.appendingPathComponent("project.gstudio"))
    }
}
