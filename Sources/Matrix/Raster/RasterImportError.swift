//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RasterImportError.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Errors thrown by `importGeoTIFF`.
public enum RasterImportError: LocalizedError, Equatable {
    /// The file couldn't be read from disk.
    case unreadable(String)
    /// The file isn't a TIFF, or its structure is damaged.
    case malformedTIFF(String)
    /// The TIFF uses a feature the reader doesn't handle (a compression scheme, bit depth or layout).
    case unsupportedTIFF(String)
    /// The file has more than one band; only single-band rasters are supported.
    case multipleBands(Int)
    /// The TIFF has no GeoTIFF georeferencing tags.
    case missingGeoreference
    /// The image is rotated or sheared relative to its coordinate axes.
    case rotatedGrid
    /// The raster isn't in a supported coordinate system: EPSG:4326 or EPSG:4269 longitude and latitude, or a
    /// UTM or Albers equal-area projection in metres.
    case unsupportedCoordinateSystem(String)
    /// The crop area doesn't overlap the raster.
    case cropOutsideRaster

    /// A user-presentable description of the failure.
    public var errorDescription: String? {
        switch self {
        case .unreadable(let detail):
            "The raster file couldn't be read: \(detail)."
        case .malformedTIFF(let detail):
            "The file isn't a valid TIFF: \(detail)."
        case .unsupportedTIFF(let detail):
            "This TIFF uses a feature that isn't supported: \(detail)."
        case .multipleBands(let count):
            "The raster has \(count) bands. Only single-band rasters can be imported; save each band as its own file."
        case .missingGeoreference:
            "The TIFF has no GeoTIFF georeferencing, so its location is unknown."
        case .rotatedGrid:
            "The raster's grid is rotated, which isn't supported."
        case .unsupportedCoordinateSystem(let detail):
            "The raster must be in longitude and latitude (EPSG:4326 or EPSG:4269) or a UTM or Albers "
                + "equal-area projection in metres (found \(detail)). Reproject it first, for example with "
                + "terra::project(x, \"EPSG:4326\")."
        case .cropOutsideRaster:
            "The study area doesn't overlap the raster."
        }
    }
}
