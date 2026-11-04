//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  CellStepGeometry.swift
//  Matrix
//
//  Step lengths for a raster's cell graph. Every cell in a row has the same
//  shape, so one row needs only three lengths: east–west within the row, and
//  north–south and diagonal to the row below. A diagonal step to the south-east
//  and one to the south-west are mirror images, so they're the same length.
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The lengths of the steps between neighbouring cells, row by row.
struct CellStepGeometry: Sendable {
    /// The east–west step within each row.
    let eastWest: [Double]
    /// The north–south step from each row to the next; one fewer than the rows.
    let northSouth: [Double]
    /// The diagonal step from each row to the next; one fewer than the rows.
    let diagonal: [Double]
    /// The latitude of the boundary below each row, in degrees, or `nil` for a projected raster.
    let boundaryLatitudes: [Double]?

    /// The geometry of a raster's cells.
    ///
    /// - Parameters:
    ///   - raster: The raster.
    ///   - stepLength: Ground metres, or cell counts.
    /// - Returns: `nil` if a geodesic between neighbouring cell centres can't be computed.
    init?(raster: Raster, stepLength: CellGraph.StepLength) {
        let rows = raster.rows
        boundaryLatitudes = raster.crs.isGeographic
            ? (0 ..< max(rows - 1, 0)).map { raster.extent.north - Double($0 + 1) * raster.cellHeight }
            : nil
        switch stepLength {
        case .cellSteps:
            eastWest = Array(repeating: 1, count: rows)
            northSouth = Array(repeating: 1, count: max(rows - 1, 0))
            diagonal = Array(repeating: 2.0.squareRoot(), count: max(rows - 1, 0))
        case .ground where !raster.crs.isGeographic:
            let (width, height) = (raster.cellWidth, raster.cellHeight)
            eastWest = Array(repeating: width, count: rows)
            northSouth = Array(repeating: height, count: max(rows - 1, 0))
            diagonal = Array(repeating: (width * width + height * height).squareRoot(), count: max(rows - 1, 0))
        case .ground:
            let ellipsoid = raster.crs.ellipsoid
            func length(_ a: (x: Double, y: Double), _ b: (x: Double, y: Double)) -> Double? {
                ellipsoid.distance(fromLongitude: a.x, latitude: a.y, toLongitude: b.x, latitude: b.y)
            }
            var eastWest: [Double] = []
            var northSouth: [Double] = []
            var diagonal: [Double] = []
            for row in 0 ..< rows {
                let here = raster.cellCoordinates(row: row, col: 0)
                guard let step = length(here, raster.cellCoordinates(row: row, col: 1)) else { return nil }
                eastWest.append(step)
                guard row + 1 < rows else { continue }
                guard let down = length(here, raster.cellCoordinates(row: row + 1, col: 0)),
                      let across = length(here, raster.cellCoordinates(row: row + 1, col: 1)) else { return nil }
                northSouth.append(down)
                diagonal.append(across)
            }
            self.eastWest = eastWest
            self.northSouth = northSouth
            self.diagonal = diagonal
        }
    }
}
