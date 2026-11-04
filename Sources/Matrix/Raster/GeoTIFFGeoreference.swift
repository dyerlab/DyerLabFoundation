//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GeoTIFFGeoreference.swift
//  Matrix
//
//  Reads where a GeoTIFF sits on Earth from its tags (OGC GeoTIFF 1.1):
//  ModelPixelScale + ModelTiepoint, or ModelTransformation, plus the GeoKey
//  directory for the coordinate system. Like GDAL, a PixelIsPoint raster's
//  tie point is taken as a cell centre and shifted half a cell to the corner.
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// A GeoTIFF's extent and coordinate system.
struct GeoTIFFGeoreference: Equatable {
    /// The outer edges of the full image, in `crs` coordinates.
    let extent: RasterExtent
    /// The coordinate system.
    let crs: CoordinateReferenceSystem

    // TIFF tags.
    static let modelPixelScaleTag: UInt16 = 33550
    static let modelTiepointTag: UInt16 = 33922
    static let modelTransformationTag: UInt16 = 34264

    static let rasterTypeKey = 1025

    /// Reads the georeferencing of an image of `width × height` pixels.
    ///
    /// - Throws: ``RasterImportError/missingGeoreference``, ``RasterImportError/rotatedGrid``,
    ///   ``RasterImportError/unsupportedCoordinateSystem(_:)`` or ``RasterImportError/malformedTIFF(_:)``.
    init(tiff: TIFFFile, width: Int, height: Int) throws {
        let keys = try GeoKeyDirectory(tiff: tiff)
        crs = try CoordinateReferenceSystem(geoKeys: keys)

        var scaleX: Double
        var scaleY: Double
        var originX: Double
        var originY: Double
        if let transform = try tiff.doubles(Self.modelTransformationTag), transform.count >= 16 {
            guard transform[1] == 0, transform[4] == 0 else { throw RasterImportError.rotatedGrid }
            scaleX = transform[0]
            scaleY = -transform[5]
            originX = transform[3]
            originY = transform[7]
        } else if let scale = try tiff.doubles(Self.modelPixelScaleTag), scale.count >= 2,
                  let tiepoint = try tiff.doubles(Self.modelTiepointTag), tiepoint.count >= 6 {
            scaleX = scale[0]
            scaleY = scale[1]
            originX = tiepoint[3] - tiepoint[0] * scaleX
            originY = tiepoint[4] + tiepoint[1] * scaleY
        } else {
            throw RasterImportError.missingGeoreference
        }
        guard scaleX > 0, scaleY > 0 else {
            throw RasterImportError.unsupportedTIFF("a grid that isn't north-up")
        }
        if keys.shorts[Self.rasterTypeKey] == 2 {
            originX -= scaleX / 2
            originY += scaleY / 2
        }
        let west = originX
        let north = originY
        let east = originX + Double(width) * scaleX
        let south = originY - Double(height) * scaleY
        if crs.isGeographic {
            guard let bounds = Self.clampedBounds(west: west, east: east, south: south, north: north) else {
                throw RasterImportError.unsupportedCoordinateSystem(
                    "an extent of \(west)…\(east), \(south)…\(north), which isn't in degrees")
            }
            extent = RasterExtent(bounds)
        } else {
            guard let projected = RasterExtent(west: west, east: east, south: south, north: north),
                  crs.geographicBounds(enclosing: projected) != nil else {
                throw RasterImportError.unsupportedCoordinateSystem(
                    "an extent of \(west)…\(east), \(south)…\(north) m that falls off the projection's map")
            }
            extent = projected
        }
    }

    /// Bounds with edges that overshoot ±180° or ±90° by rounding pulled back in range.
    private static func clampedBounds(west: Double, east: Double, south: Double,
                                      north: Double) -> GeographicBounds? {
        let tolerance = 1e-6
        func clamp(_ value: Double, _ limit: Double) -> Double {
            abs(value) > limit && abs(value) - limit < tolerance ? (value < 0 ? -limit : limit) : value
        }
        return GeographicBounds(west: clamp(west, 180), east: clamp(east, 180),
                                south: clamp(south, 90), north: clamp(north, 90))
    }
}
