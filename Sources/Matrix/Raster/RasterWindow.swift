//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RasterWindow.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The block of cells in a grid that overlaps an extent, with the block's own extent.
struct RasterWindow: Equatable {
    /// The rows kept, 0 at the grid's north edge.
    let rowRange: Range<Int>
    /// The columns kept, 0 at the grid's west edge.
    let colRange: Range<Int>
    /// The outer edges of the kept cells.
    let extent: RasterExtent

    var rows: Int { rowRange.count }
    var cols: Int { colRange.count }

    /// The window of a `rows × cols` grid spanning `gridExtent` that covers `target`, or `nil` if they don't
    /// overlap.
    init?(covering target: RasterExtent, gridExtent: RasterExtent, rows: Int, cols: Int) {
        guard let overlap = target.intersection(gridExtent) else { return nil }
        let cellWidth = gridExtent.width / Double(cols)
        let cellHeight = gridExtent.height / Double(rows)
        // A crop edge that lands on a cell edge, give or take rounding, shouldn't pull in the neighbouring cell.
        let tolerance = 1e-9
        let firstCol = max(Int(((overlap.west - gridExtent.west) / cellWidth + tolerance).rounded(.down)), 0)
        let endCol = min(Int(((overlap.east - gridExtent.west) / cellWidth - tolerance).rounded(.up)), cols)
        let firstRow = max(Int(((gridExtent.north - overlap.north) / cellHeight + tolerance).rounded(.down)), 0)
        let endRow = min(Int(((gridExtent.north - overlap.south) / cellHeight - tolerance).rounded(.up)), rows)
        // Take the grid's own edges where the window reaches them, so rounding can't push a ±180/±90 edge
        // out of range.
        let west = firstCol == 0 ? gridExtent.west : gridExtent.west + Double(firstCol) * cellWidth
        let east = endCol == cols ? gridExtent.east : gridExtent.west + Double(endCol) * cellWidth
        let north = firstRow == 0 ? gridExtent.north : gridExtent.north - Double(firstRow) * cellHeight
        let south = endRow == rows ? gridExtent.south : gridExtent.north - Double(endRow) * cellHeight
        guard firstCol < endCol, firstRow < endRow,
              let extent = RasterExtent(west: west, east: east, south: south, north: north) else {
            return nil
        }
        rowRange = firstRow ..< endRow
        colRange = firstCol ..< endCol
        self.extent = extent
    }

    /// The whole of a `rows × cols` grid.
    init(wholeGrid gridExtent: RasterExtent, rows: Int, cols: Int) {
        rowRange = 0 ..< rows
        colRange = 0 ..< cols
        extent = gridExtent
    }
}
