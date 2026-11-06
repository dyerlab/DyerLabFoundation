//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GraphsFileContents.swift
//  PopulationGenetics
//
//  What a `.graphs` file says about its graph.
//
//  Created by Rodney Dyer on 2026.11.05.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The graph in a `.graphs` file, with what identifies it. The file's other
/// components are left on disk rather than being decoded here.
public struct GraphsFileContents: Sendable {

    /// The project's name.
    public var projectName: String

    /// The graph, with its strata and values.
    public var graph: PopulationGraphDataset

    /// The names of the loci the graph was built from.
    public var locusReferences: [String]

    /// Creates the contents of a `.graphs` file.
    ///
    /// - Parameters:
    ///   - projectName: The project's name.
    ///   - graph: The graph, with its strata and values.
    ///   - locusReferences: The names of the loci the graph was built from.
    public init(projectName: String, graph: PopulationGraphDataset, locusReferences: [String] = []) {
        self.projectName = projectName
        self.graph = graph
        self.locusReferences = locusReferences
    }
}
