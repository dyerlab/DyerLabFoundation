//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ProjectStore+Snapshot.swift
//  PopulationGenetics
//
//  saveSnapshot/loadSnapshot: the read/write pair for "persist (or
//  reconstruct) everything a document currently holds in memory, in one
//  call" — a generalization of `save(_:...)`/`load(from:)` (ProjectStore.swift)
//  that covers all five `StoreComponents`, not just `.geneticData`. Meant for
//  a document-style caller's Cmd+S/autosave path, not for incremental
//  mutation — hold a `ProjectStore` open via `openOrCreate(at:)` and call
//  `writeGeneticData`/`writeGraph`/`addResult`/`appendLog`/`addMatrix`
//  directly if only one component changed.
//
//  Created by Rodney Dyer on 2026.07.25.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import PresentationZen

extension ProjectStore {

    /// Persists everything the caller currently holds in memory as a
    /// brand-new file at `url`, atomically. Which `StoreComponents` the file
    /// ends up with is derived from which arguments are non-nil/non-empty —
    /// no separate `components:` argument to keep in sync with the rest.
    ///
    /// Unlike `create(overwrite:true)` used directly, this is safe to call on
    /// every save: the new content is built up entirely in a sibling temporary
    /// file, and `url` is only touched — via an atomic filesystem replace —
    /// once every write below has succeeded. If anything throws partway
    /// (a bad encoding, a full disk), the file at `url` is left exactly as it
    /// was; only the discarded temp file is affected. (`writeGeneticData`/
    /// `writeGraph` each wrap themselves in their own SQLite transaction, so
    /// they can't be nested under one outer transaction spanning this whole
    /// sequence — the temp-file swap is what makes the *file* atomic instead.)
    ///
    /// - Parameters:
    ///   - dataset: The genetic dataset (matrix/parentage/strata), or `nil` for none.
    ///   - graph: The population graph and its metadata, or `nil` for none.
    ///   - results: Every analysis result to store.
    ///   - logEntries: Every log entry to store.
    ///   - matrices: Every named matrix attachment to store.
    ///   - projectName: The project's name, written unconditionally.
    ///   - species: Optional species this project concerns.
    ///   - description: Optional free-text description of the project.
    ///   - url: Destination file URL. Its prior contents (if any) are only
    ///     replaced once the new file is fully and successfully built.
    /// - Throws: Any ``PersistenceError`` from building the temporary file, or a file-system error from
    ///   replacing `url`. In either case `url` is left unchanged.
    public static func saveSnapshot(dataset: ImportedDataset? = nil, graph: PopulationGraphDataset? = nil,
                                     results: [AnalysisResult] = [], logEntries: [LogEntry] = [],
                                     matrices: [MatrixAttachment] = [],
                                     projectName: String, species: String? = nil, description: String? = nil,
                                     to url: URL) async throws {
        var components: StoreComponents = []
        if dataset != nil { components.insert(.geneticData) }
        if graph != nil { components.insert(.graph) }
        if !results.isEmpty { components.insert(.results) }
        if !logEntries.isEmpty { components.insert(.log) }
        if !matrices.isEmpty { components.insert(.matrices) }

        let tempURL = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")

        let store = ProjectStore()
        do {
            try await store.create(at: tempURL, overwrite: true, components: components, projectName: projectName,
                                    species: species, description: description)
            if let dataset {
                try await store.writeGeneticData(matrix: dataset.matrix, parentage: dataset.parentage,
                                                  strata: dataset.strata)
            }
            if let graph {
                try await store.writeGraph(graph.graph, nodeStrata: graph.nodeStrata, nodeValues: graph.nodeValues,
                                            edgeValues: graph.edgeValues, graphValues: graph.graphValues,
                                            loci: graph.loci)
            }
            for result in results {
                try await store.addResult(result)
            }
            for entry in logEntries {
                try await store.appendLog(entry)
            }
            for matrix in matrices {
                try await store.addMatrix(matrix.data, name: matrix.name, description: matrix.description)
            }
            await store.close()
        } catch {
            await store.close()
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
    }

    /// Reads everything currently stored at `url` in one call — the read-side
    /// counterpart to `saveSnapshot`. Only reads whichever components
    /// `presentComponents` reports for this file; a component absent from the
    /// file comes back `nil`/empty in the returned snapshot, not an error.
    ///
    /// - Parameter url: The project file's location.
    /// - Returns: Every component present in the file.
    /// - Throws: Any ``PersistenceError`` from opening the file or reading a present component.
    public static func loadSnapshot(from url: URL) async throws -> ProjectSnapshot {
        let store = ProjectStore()
        try await store.open(at: url, mode: .readOnly)
        let summary = try await store.readSummary()
        let present = await store.presentComponents

        let dataset = present.contains(.geneticData) ? try await store.readDataset() : nil
        let graph = present.contains(.graph) ? try await store.readGraph() : nil
        let results = present.contains(.results) ? try await store.results() : []
        let logEntries = present.contains(.log) ? try await store.logEntries() : []

        var matrices: [MatrixAttachment] = []
        if present.contains(.matrices) {
            var seenNames: Set<String> = []
            for info in try await store.matrices() where seenNames.insert(info.name).inserted {
                if let data = try await store.matrixData(named: info.name) {
                    matrices.append(MatrixAttachment(name: info.name, description: info.description, data: data))
                }
            }
        }

        await store.close()
        return ProjectSnapshot(projectName: summary.projectName, species: summary.species,
                                description: summary.description, dataset: dataset, graph: graph, results: results,
                                logEntries: logEntries, matrices: matrices)
    }
}
