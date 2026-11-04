//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  CellGraph+Notes.swift
//  Matrix
//
//  The log entries a cell graph carries: how it was built, and when the
//  raster's geometry deserves a warning. Ground step lengths make the
//  longitude/latitude grid close to exact at any extent, so the warnings are
//  about cell size and latitude, not the size of the study area:
//
//  - Coarse cells (half a degree or more), where a cell's width changes
//    noticeably between its north and south edges.
//  - High latitude (beyond 60°), where east–west steps are under half the
//    length of north–south ones and 8-neighbour moves become lopsided.
//  - Cell counting on a geographic grid, giving the size of the bias.
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension CellGraph {

    /// The notes describing a cell graph.
    static func notes(resistance: Raster,
                      neighbours: Neighbours,
                      stepLength: StepLength,
                      referenceWalk: ReferenceWalk,
                      impassable: Int,
                      regionCount: Int) -> [AnalysisNote] {
        typealias Report = AnalysisReport
        let geographic = resistance.crs.isGeographic
        var notes: [AnalysisNote] = []

        var built = "The resistance surface \"\(resistance.name)\" (\(Report.count(resistance.rows)) × "
            + "\(Report.count(resistance.cols)) cells) was treated as a graph joining each cell to its "
            + "\(neighbours.rawValue) neighbours"
        built += impassable == 0 ? "."
            : "; \(Report.count(impassable)) \(impassable == 1 ? "cell" : "cells") without a value "
                + "\(impassable == 1 ? "was" : "were") impassable."
        notes.append(AnalysisNote(.assumption, built))

        switch stepLength {
        case .ground:
            let length = geographic ? "geodesic distance between the cell centres" : "grid distance in metres"
            notes.append(AnalysisNote(.assumption, "Each step cost the \(length) times the mean resistance of "
                + "the two cells, as gdistance's geoCorrection(type = \"c\") does."))
        case .cellSteps:
            notes.append(AnalysisNote(.assumption, "Each step cost the mean resistance of the two cells, times √2 "
                + "for a diagonal step; cell sizes were ignored."))
        }

        if geographic && referenceWalk == .areaCorrected {
            notes.append(AnalysisNote(.assumption, "The reference random walk moved in proportion to each step's "
                + "conductance (1/cost), with steps between rows also weighted by the cosine of their latitude, "
                + "as geoCorrection(type = \"r\") does, so that the walk spreads evenly over cells that narrow "
                + "toward the pole. Step costs were not changed."))
        } else {
            notes.append(AnalysisNote(.assumption, "The reference random walk moved in proportion to each step's "
                + "conductance (1/cost)."))
        }

        if regionCount > 1 {
            notes.append(AnalysisNote(.warning, "The passable cells form \(Report.count(regionCount)) separate "
                + "regions; sites in different regions are infinitely far apart."))
        }

        if geographic {
            notes.append(contentsOf: geographicWarnings(resistance: resistance, stepLength: stepLength))
        } else if stepLength == .cellSteps, abs(resistance.cellWidth / resistance.cellHeight - 1) > 1e-6 {
            let ratio = resistance.cellWidth / resistance.cellHeight
            notes.append(AnalysisNote(.warning, "Cells are \(Report.number(resistance.cellWidth)) m wide and "
                + "\(Report.number(resistance.cellHeight)) m tall, so counting cells misweights east–west moves "
                + "by \(Report.number(abs(1 - ratio) * 100))% relative to north–south ones."))
        }
        return notes
    }

    /// Warnings about a longitude/latitude grid's cell size and latitude.
    private static func geographicWarnings(resistance: Raster, stepLength: StepLength) -> [AnalysisNote] {
        typealias Report = AnalysisReport
        let radians = Double.pi / 180
        let height = resistance.cellHeight
        let northCentre = resistance.extent.north - height / 2
        let southCentre = resistance.extent.south + height / 2
        let poleward = max(abs(resistance.extent.north), abs(resistance.extent.south))
        var notes: [AnalysisNote] = []

        if height >= 0.5 {
            // How much a cell next to the poleward edge narrows from one side of it to the other.
            let edge = min(poleward, 89.9)
            let inner = max(edge - height, 0)
            let change = (1 - cos(edge * radians) / cos(inner * radians)) * 100
            notes.append(AnalysisNote(.warning, "Cells are \(Report.number(height))° tall, so a cell's width "
                + "changes by up to \(Report.number(change))% between its north and south edges; step lengths "
                + "are measured between cell centres and don't capture that."))
        }
        if poleward > 60 {
            let ratio = cos(min(poleward, 89.9) * radians) * resistance.cellWidth / height
            notes.append(AnalysisNote(.warning, "The surface reaches \(Report.number(poleward))° of latitude, where "
                + "an east–west step is \(Report.number(ratio * 100))% of the length of a north–south one, so "
                + "8-neighbour moves are strongly lopsided."))
        }
        if stepLength == .cellSteps {
            let shortfalls = [northCentre, southCentre].map { (1 - cos($0 * radians) * resistance.cellWidth / height) * 100 }
            let (low, high) = (shortfalls.min()!, shortfalls.max()!)
            notes.append(AnalysisNote(.warning, "Steps were counted in cells, but an east–west step here is "
                + "\(Report.number(low))% to \(Report.number(high))% shorter on the ground than a north–south one "
                + "(1 − cos latitude), so east–west moves are over-weighted by that much."))
        }
        return notes
    }
}
