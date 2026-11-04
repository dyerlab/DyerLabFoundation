//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  CellGraph+Options.swift
//  Matrix
//
//  How a cell graph is built from a resistance raster.
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension CellGraph {

    /// Which cells a cell is joined to.
    public enum Neighbours: Int, Sendable, Hashable, Codable {
        /// The four cells sharing an edge (gdistance `directions = 4`).
        case four = 4
        /// The four edge cells and the four diagonal cells (gdistance `directions = 8`).
        case eight = 8
    }

    /// How long a step between two cells is.
    public enum StepLength: Sendable, Hashable, Codable {
        /// The ground distance between the cell centres in metres: the geodesic on the ellipsoid for a
        /// longitude/latitude raster, grid metres for a projected one. This is gdistance's
        /// `geoCorrection(type = "c")`.
        case ground
        /// One per edge step and √2 per diagonal step, ignoring the cells' real sizes. Useful for seeing how
        /// much the ground correction matters on a dataset.
        case cellSteps
    }

    /// How the reference random walk, the walk RSP departs from as θ grows, chooses its next cell.
    public enum ReferenceWalk: Sendable, Hashable, Codable {
        /// In proportion to each step's conductance, 1 / cost, as stock gdistance `rSPDistance()` does after
        /// `geoCorrection(type = "c")`.
        case conductance
        /// As ``conductance``, with every step between rows of a longitude/latitude raster also multiplied by
        /// the cosine of its latitude, as `geoCorrection(type = "r")` does. That makes the walk a proper
        /// diffusion over cells whose east–west width shrinks with latitude. Step costs are unchanged.
        /// A projected raster's cells are all the same size, so there this is the same as ``conductance``.
        case areaCorrected
    }
}
