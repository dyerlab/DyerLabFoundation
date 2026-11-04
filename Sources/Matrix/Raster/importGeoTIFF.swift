//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  importGeoTIFF.swift
//  Matrix
//
//  The file is memory-mapped and only the strips or tiles that overlap the
//  crop area are decoded, so a study area can be cut from a state-wide DEM
//  without reading the whole thing into memory.
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Reads a single-band GeoTIFF file as a ``Raster``, optionally cropped to a study area.
///
/// The raster must be in longitude and latitude (EPSG:4326 or EPSG:4269), or projected in metres by a UTM
/// zone or an Albers equal-area projection, named by EPSG code or by custom parameters (see
/// ``CoordinateReferenceSystem``). A projected raster keeps its own grid; it isn't resampled. Supported files
/// are classic TIFF or BigTIFF, stripped or tiled, uncompressed or compressed with LZW, Deflate or PackBits
/// (with or without a predictor), holding 8-, 16- or 32-bit integers or 32- or 64-bit floats. These cover what
/// R's `terra::writeRaster()` and GDAL write by default. The GDAL no-data value becomes `Float.nan`.
///
/// - Parameters:
///   - url: The GeoTIFF file.
///   - name: The layer's name. Defaults to the file name without its extension.
///   - area: The study area to keep, or `nil` for the whole raster. Every cell overlapping it is kept, so the
///     result's extent snaps outward to cell edges. For a projected raster the area is projected first and the
///     smallest grid rectangle enclosing it is kept.
/// - Returns: The raster.
/// - Throws: ``RasterImportError/unreadable(_:)`` if the file can't be read, ``RasterImportError/cropOutsideRaster``
///   if `area` doesn't overlap it, or any other ``RasterImportError`` for a file that isn't a supported GeoTIFF.
public func importGeoTIFF(contentsOf url: URL,
                          name: String? = nil,
                          cropTo area: GeographicBounds? = nil) throws -> Raster {
    let data: Data
    do {
        data = try Data(contentsOf: url, options: .alwaysMapped)
    } catch {
        throw RasterImportError.unreadable(error.localizedDescription)
    }
    return try importGeoTIFF(data: data, name: name ?? url.deletingPathExtension().lastPathComponent, cropTo: area)
}

/// Reads a single-band GeoTIFF from memory as a ``Raster``, optionally cropped to a study area.
///
/// See ``importGeoTIFF(contentsOf:name:cropTo:)`` for the files supported.
///
/// - Parameters:
///   - data: The GeoTIFF's bytes.
///   - name: The layer's name.
///   - area: The study area to keep, or `nil` for the whole raster.
/// - Returns: The raster.
/// - Throws: ``RasterImportError/cropOutsideRaster`` if `area` doesn't overlap the raster, or any other
///   ``RasterImportError`` for data that isn't a supported GeoTIFF.
public func importGeoTIFF(data: Data, name: String, cropTo area: GeographicBounds? = nil) throws -> Raster {
    let tiff = try TIFFFile(data: data)
    let layout = try TIFFImageLayout(tiff: tiff)
    let georeference = try GeoTIFFGeoreference(tiff: tiff, width: layout.width, height: layout.height)

    let window: RasterWindow
    if let area {
        guard let target = georeference.crs.extent(enclosing: area),
              let covering = RasterWindow(covering: target, gridExtent: georeference.extent,
                                          rows: layout.height, cols: layout.width) else {
            throw RasterImportError.cropOutsideRaster
        }
        window = covering
    } else {
        window = RasterWindow(wholeGrid: georeference.extent, rows: layout.height, cols: layout.width)
    }

    var values = [Float](repeating: .nan, count: window.rows * window.cols)
    let reader = tiff.reader
    let firstBlockRow = window.rowRange.lowerBound / layout.blockHeight
    let lastBlockRow = (window.rowRange.upperBound - 1) / layout.blockHeight
    let firstBlockCol = window.colRange.lowerBound / layout.blockWidth
    let lastBlockCol = (window.colRange.upperBound - 1) / layout.blockWidth
    for blockRow in firstBlockRow ... lastBlockRow {
        let blockRows = layout.pixelRows(ofBlockRow: blockRow)
        let rows = blockRows.clamped(to: window.rowRange)
        for blockCol in firstBlockCol ... lastBlockCol {
            let blockCols = layout.pixelCols(ofBlockCol: blockCol)
            let cols = blockCols.clamped(to: window.colRange)
            let block = try layout.decodeBlock(row: blockRow, col: blockCol, reader: reader)
            for row in rows {
                let source = (row - blockRows.lowerBound) * layout.blockWidth + (cols.lowerBound - blockCols.lowerBound)
                let destination = (row - window.rowRange.lowerBound) * window.cols
                    + (cols.lowerBound - window.colRange.lowerBound)
                for offset in 0 ..< cols.count {
                    values[destination + offset] = block[source + offset]
                }
            }
        }
    }

    guard let raster = Raster(name: name, rows: window.rows, cols: window.cols, extent: window.extent,
                              crs: georeference.crs, values: values) else {
        throw RasterImportError.unsupportedCoordinateSystem("an extent that falls off the projection's map")
    }
    return raster
}
