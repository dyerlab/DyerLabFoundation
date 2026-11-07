//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ProjectSnapshot+Figures.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import PresentationZen

public extension ProjectSnapshot {

    /// The project with each figure that can follow the genotypes recomputed from them.
    ///
    /// Do this just before writing a file, so that what R reads there matches the file's genotypes. It can be slow
    /// for a large dataset, so keep it off the main actor.
    ///
    /// - Returns: The refreshed project, or the project unchanged if it has no genotypes.
    func refreshingFigures() -> ProjectSnapshot {
        guard let dataset, !figures.isEmpty else { return self }
        return ProjectSnapshot(projectName: projectName,
                               species: species,
                               description: description,
                               metadata: metadata,
                               dataset: dataset,
                               graph: graph,
                               results: results,
                               logEntries: logEntries,
                               matrices: matrices,
                               rasters: rasters,
                               figures: figures.map { $0.refreshed(from: dataset) })
    }
}
