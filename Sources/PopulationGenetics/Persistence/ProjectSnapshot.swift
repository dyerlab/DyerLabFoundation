//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ProjectSnapshot.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.07.25.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import PresentationZen

/// The full contents of a `ProjectStore` file, read or written in one call —
/// the read-side counterpart to `saveSnapshot`'s arguments. Every field here
/// mirrors one `StoreComponents` case; `nil`/empty means that component isn't
/// present in the file (or wasn't given to `saveSnapshot`), not that it's
/// present-but-empty.
public struct ProjectSnapshot: Sendable {
    /// Every project-metadata pair: the reserved `ProjectStore.MetadataKey`
    /// keys plus any app-defined ones.
    public let metadata: [String: String]
    /// The project's name. Always present, written unconditionally at `create` time.
    public var projectName: String { metadata[ProjectStore.MetadataKey.projectName] ?? "" }
    /// The species this project concerns, if given.
    public var species: String? { metadata[ProjectStore.MetadataKey.species] }
    /// Free-text description of what this project is focused on.
    public var description: String? { metadata[ProjectStore.MetadataKey.description] }
    /// The genetic dataset (matrix, parentage, strata), if `.geneticData` is present.
    public let dataset: ImportedDataset?
    /// The population graph and its metadata, if `.graph` is present.
    public let graph: PopulationGraphDataset?
    /// Every stored analysis result, in insertion order.
    public let results: [AnalysisResult]
    /// Every stored log entry, in insertion order.
    public let logEntries: [LogEntry]
    /// Every currently-named matrix attachment (latest version per name).
    public let matrices: [MatrixAttachment]

    /// Initializes a new project snapshot.
    ///
    /// - Parameters:
    ///   - projectName: The project's name.
    ///   - species: The species this project concerns, if any.
    ///   - description: Free-text description of the project.
    ///   - metadata: Other project metadata. The identity arguments above win over the
    ///     same `ProjectStore.MetadataKey` keys here, and empty values are dropped.
    ///   - dataset: The genetic dataset, or `nil` for none.
    ///   - graph: The population graph, or `nil` for none.
    ///   - results: Every analysis result.
    ///   - logEntries: Every log entry.
    ///   - matrices: Every named matrix attachment.
    public init(projectName: String, species: String? = nil, description: String? = nil,
                metadata: [String: String] = [:], dataset: ImportedDataset? = nil, graph: PopulationGraphDataset? = nil,
                results: [AnalysisResult] = [], logEntries: [LogEntry] = [], matrices: [MatrixAttachment] = []) {
        self.metadata = ProjectStore.initialMetadata(metadata, projectName: projectName, species: species,
                                                     description: description)
        self.dataset = dataset
        self.graph = graph
        self.results = results
        self.logEntries = logEntries
        self.matrices = matrices
    }
}
