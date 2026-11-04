//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Raster+Geometry.swift
//  Matrix
//
//  Cell geometry, point lookup and cropping. Cells in a geographic raster are
//  equal in degrees but not on the ground: a cell's east–west width shrinks
//  with the cosine of its latitude. `cellSize(atRow:)` gives ground sizes so
//  later resistance-distance work doesn't treat cells as square. A projected
//  raster's cells are already in metres.
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension Raster {

    /// The width of one cell in ``crs`` units: degrees of longitude, or metres.
    public var cellWidth: Double { extent.width / Double(cols) }

    /// The height of one cell in ``crs`` units: degrees of latitude, or metres.
    public var cellHeight: Double { extent.height / Double(rows) }

    /// The centre of one cell in ``crs`` coordinates.
    ///
    /// - Parameters:
    ///   - row: The row, 0 at the north edge.
    ///   - col: The column, 0 at the west edge.
    /// - Returns: The centre's x and y: longitude and latitude, or easting and northing in metres.
    public func cellCoordinates(row: Int, col: Int) -> (x: Double, y: Double) {
        (extent.west + (Double(col) + 0.5) * cellWidth, extent.north - (Double(row) + 0.5) * cellHeight)
    }

    /// The longitude and latitude of one cell's centre.
    ///
    /// - Parameters:
    ///   - row: The row, 0 at the north edge.
    ///   - col: The column, 0 at the west edge.
    /// - Returns: The cell centre's longitude and latitude, in degrees.
    public func cellCenter(row: Int, col: Int) -> (longitude: Double, latitude: Double) {
        let point = cellCoordinates(row: row, col: col)
        // Every cell centre lies inside an extent whose edges were checked at init, so this always succeeds.
        return crs.geographic(x: point.x, y: point.y) ?? (.nan, .nan)
    }

    /// The cell containing a point given in ``crs`` coordinates.
    ///
    /// A point on the boundary between two cells belongs to the one to its south-east; points on the
    /// raster's east or south edge belong to the last column or row.
    ///
    /// - Parameters:
    ///   - x: The point's x: longitude, or easting in metres.
    ///   - y: The point's y: latitude, or northing in metres.
    /// - Returns: The cell's row and column, or `nil` if the point is outside the raster.
    public func cell(x: Double, y: Double) -> (row: Int, col: Int)? {
        guard extent.contains(x: x, y: y) else { return nil }
        let col = min(Int(((x - extent.west) / cellWidth).rounded(.down)), cols - 1)
        let row = min(Int(((extent.north - y) / cellHeight).rounded(.down)), rows - 1)
        return (row, col)
    }

    /// The cell containing a longitude and latitude.
    ///
    /// - Parameters:
    ///   - longitude: The point's longitude, in degrees.
    ///   - latitude: The point's latitude, in degrees.
    /// - Returns: The cell's row and column, or `nil` if the point is outside the raster.
    public func cell(longitude: Double, latitude: Double) -> (row: Int, col: Int)? {
        guard let point = crs.coordinates(longitude: longitude, latitude: latitude) else { return nil }
        return cell(x: point.x, y: point.y)
    }

    /// The value of the cell containing a longitude and latitude.
    ///
    /// - Parameters:
    ///   - longitude: The point's longitude, in degrees.
    ///   - latitude: The point's latitude, in degrees.
    /// - Returns: The value, or `nil` if the point is outside the raster or its cell is missing.
    public func value(longitude: Double, latitude: Double) -> Float? {
        guard let cell = cell(longitude: longitude, latitude: latitude) else { return nil }
        return value(row: cell.row, col: cell.col)
    }

    /// The ground size of the cells in one row, in metres.
    ///
    /// For a geographic raster this uses a spherical Earth of mean radius 6,371,008.8 m at the row's central
    /// latitude, within about 0.5% of the WGS 84 ellipsoid. For a projected raster it is the cell size in
    /// grid metres, the same for every row. Grid metres carry the projection's own scale error: under 0.1%
    /// inside a UTM zone, and up to about 1.3% for CONUS Albers between and beyond its standard parallels.
    ///
    /// - Parameter row: The row, 0 at the north edge.
    /// - Returns: The east–west width and north–south height of a cell in that row, in metres.
    public func cellSize(atRow row: Int) -> (width: Double, height: Double) {
        guard crs.isGeographic else { return (cellWidth, cellHeight) }
        let radius = 6_371_008.8
        let latitude = cellCoordinates(row: row, col: 0).y * .pi / 180
        let height = radius * cellHeight * .pi / 180
        let width = radius * cellWidth * .pi / 180 * cos(latitude)
        return (width, height)
    }

    /// The part of this raster covering a longitude/latitude area.
    ///
    /// For a projected raster, the area is first projected and the smallest grid rectangle enclosing it is
    /// kept. Every overlapping cell is kept, so the result snaps outward to cell edges.
    ///
    /// - Parameter area: The area to keep.
    /// - Returns: The cropped raster, or `nil` if `area` doesn't overlap this raster.
    public func cropped(to area: GeographicBounds) -> Raster? {
        guard let target = crs.extent(enclosing: area) else { return nil }
        return cropped(to: target)
    }

    /// The part of this raster covering an extent in its own coordinates.
    ///
    /// Every cell that overlaps `target` is kept, so the result's extent snaps outward to cell edges and can
    /// be slightly larger than `target`, as `terra::crop(x, e, snap = "out")` does.
    ///
    /// - Parameter target: The extent to keep, in ``crs`` coordinates.
    /// - Returns: The cropped raster, or `nil` if `target` doesn't overlap this raster.
    public func cropped(to target: RasterExtent) -> Raster? {
        guard let window = RasterWindow(covering: target, gridExtent: extent, rows: rows, cols: cols) else {
            return nil
        }
        var cropped: [Float] = []
        cropped.reserveCapacity(window.rows * window.cols)
        for row in window.rowRange {
            let start = row * cols + window.colRange.lowerBound
            cropped.append(contentsOf: values[start ..< start + window.cols])
        }
        return Raster(name: name, rows: window.rows, cols: window.cols, extent: window.extent, crs: crs,
                      values: cropped)
    }
}
