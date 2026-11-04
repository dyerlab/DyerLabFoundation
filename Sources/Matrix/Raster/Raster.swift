//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Raster.swift
//  Matrix
//
//  A value type rather than a `Matrix` subclass: `Matrix` is a non-`Sendable`
//  class of `Double`s with row/column names, while a raster has to cross actor
//  boundaries (import off the main actor, `ProjectStore`) and can run to tens
//  of millions of cells, where `Float` halves the memory. `makeMatrix()`
//  converts when the linear algebra is wanted.
//
//  Rasters are either geographic (EPSG:4326 or 4269) or projected in metres
//  by UTM or Albers (see CoordinateReferenceSystem). Anything else must be
//  reprojected before import, e.g. with `terra::project(x, "EPSG:4326")`.
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// A single-band grid of values over a rectangular extent.
///
/// The grid is laid out in a ``CoordinateReferenceSystem``: longitude and latitude, or metres in a UTM or
/// Albers projection. Cells are stored row-major with the northernmost row first, matching how GeoTIFFs and
/// R's `terra` order them. Missing cells (a GeoTIFF's no-data value, or `NA` in R) are `Float.nan`.
///
/// Categorical data such as NLCD land cover is brought in one class at a time, as its own raster layer (for
/// example, 1 where a cell is forest and 0 where it isn't).
///
/// ## Example
///
/// ```swift
/// let studyArea = GeographicBounds(longitudes: lons, latitudes: lats)!.buffered(by: 0.1)
/// let elevation = try importGeoTIFF(contentsOf: url, name: "elevation", cropTo: studyArea)
/// let height = elevation.value(longitude: -77.45, latitude: 37.55)
/// ```
public struct Raster: Sendable {
    /// The layer's name, e.g. `"elevation"` or `"nlcd_forest"`.
    public var name: String
    /// The number of rows (cells north to south).
    public let rows: Int
    /// The number of columns (cells west to east).
    public let cols: Int
    /// The outer edges of the grid (cell edges, not cell centres), in ``crs`` coordinates.
    public let extent: RasterExtent
    /// The coordinate system the grid is laid out in.
    public let crs: CoordinateReferenceSystem
    /// The smallest longitude/latitude area enclosing the grid. For a geographic raster this is its extent.
    public let geographicBounds: GeographicBounds
    /// The cell values, row-major with the northernmost row first; `Float.nan` marks a missing cell.
    public let values: [Float]

    /// Creates a raster from its values.
    ///
    /// - Parameters:
    ///   - name: The layer's name.
    ///   - rows: The number of rows.
    ///   - cols: The number of columns.
    ///   - extent: The outer edges of the grid, in `crs` coordinates.
    ///   - crs: The coordinate system.
    ///   - values: `rows × cols` values, row-major with the northernmost row first; `Float.nan` for missing.
    /// - Returns: `nil` if `rows` or `cols` is less than 1, `values` has the wrong length, or the extent isn't
    ///   valid in `crs` (beyond ±180°/±90°, or off the projection's map).
    public init?(name: String,
                 rows: Int,
                 cols: Int,
                 extent: RasterExtent,
                 crs: CoordinateReferenceSystem,
                 values: [Float]) {
        guard rows > 0, cols > 0, values.count == rows * cols,
              crs.epsg.map({ CoordinateReferenceSystem(epsg: $0) == crs }) ?? true,
              let bounds = crs.geographicBounds(enclosing: extent) else { return nil }
        self.name = name
        self.rows = rows
        self.cols = cols
        self.extent = extent
        self.crs = crs
        geographicBounds = bounds
        self.values = values
    }

    /// Creates a geographic raster from its values.
    ///
    /// - Parameters:
    ///   - name: The layer's name.
    ///   - rows: The number of rows.
    ///   - cols: The number of columns.
    ///   - bounds: The outer edges of the grid.
    ///   - epsg: The EPSG code, 4326 (the default) or 4269.
    ///   - values: `rows × cols` values, row-major with the northernmost row first; `Float.nan` for missing.
    /// - Returns: `nil` if `rows` or `cols` is less than 1, `values` has the wrong length, or `epsg` isn't
    ///   one of ``CoordinateReferenceSystem/geographicEPSGCodes``.
    public init?(name: String,
                 rows: Int,
                 cols: Int,
                 bounds: GeographicBounds,
                 epsg: Int = 4326,
                 values: [Float]) {
        guard CoordinateReferenceSystem.geographicEPSGCodes.contains(epsg),
              let extent = RasterExtent(west: bounds.west, east: bounds.east, south: bounds.south,
                                        north: bounds.north) else { return nil }
        self.init(name: name, rows: rows, cols: cols, extent: extent, crs: .geographic(epsg: epsg), values: values)
    }

    /// The coordinate system's EPSG code, or `nil` for a projection that has none.
    public var epsg: Int? { crs.epsg }

    /// The value of one cell, `Float.nan` if it's missing.
    ///
    /// - Parameters:
    ///   - row: The row, 0 at the north edge.
    ///   - col: The column, 0 at the west edge.
    /// - Precondition: `row` and `col` are inside the grid.
    public subscript(row: Int, col: Int) -> Float {
        precondition(row >= 0 && row < rows && col >= 0 && col < cols, "Raster cell (\(row), \(col)) out of range")
        return values[row * cols + col]
    }

    /// The value of one cell.
    ///
    /// - Parameters:
    ///   - row: The row, 0 at the north edge.
    ///   - col: The column, 0 at the west edge.
    /// - Returns: The value, or `nil` if the cell is outside the grid or missing.
    public func value(row: Int, col: Int) -> Float? {
        guard row >= 0, row < rows, col >= 0, col < cols else { return nil }
        let value = values[row * cols + col]
        return value.isNaN ? nil : value
    }

    /// The smallest and largest non-missing values, or `nil` if every cell is missing.
    public var valueRange: ClosedRange<Float>? {
        var low = Float.infinity
        var high = -Float.infinity
        for value in values where !value.isNaN {
            low = min(low, value)
            high = max(high, value)
        }
        return low <= high ? low...high : nil
    }

    /// The number of missing cells.
    public var missingCount: Int {
        values.reduce(0) { $0 + ($1.isNaN ? 1 : 0) }
    }
}

// MARK: - Equatable

extension Raster: Equatable {
    /// Two rasters are equal when their metadata match and every cell matches, counting two missing cells as equal.
    ///
    /// - Parameters:
    ///   - lhs: A raster.
    ///   - rhs: Another raster.
    /// - Returns: `true` if they hold the same layer.
    public static func == (lhs: Raster, rhs: Raster) -> Bool {
        guard lhs.name == rhs.name, lhs.rows == rhs.rows, lhs.cols == rhs.cols,
              lhs.extent == rhs.extent, lhs.crs == rhs.crs else { return false }
        // NaN never equals itself, so missing cells need their own comparison.
        return zip(lhs.values, rhs.values).allSatisfy { $0 == $1 || ($0.isNaN && $1.isNaN) }
    }
}
