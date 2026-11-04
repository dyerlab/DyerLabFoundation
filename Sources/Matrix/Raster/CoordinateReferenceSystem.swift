//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  CoordinateReferenceSystem.swift
//  Matrix
//
//  Datum shifts are ignored: a NAD83 raster's longitudes and latitudes are
//  treated as WGS 84 ones. The two differ by 1–2 m in North America, well
//  under a 30 m cell, and matching sites to cells needs no more than that.
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The coordinate system a raster's grid is laid out in.
///
/// A raster is either in longitude and latitude (WGS 84 or NAD83) or projected in metres by Transverse
/// Mercator (UTM) or Albers equal-area. Other projections, such as Lambert conformal conic, aren't supported.
///
/// ```swift
/// let nlcd = CoordinateReferenceSystem(epsg: 5070)!       // NAD83 / CONUS Albers
/// nlcd.definition                                          // "EPSG:5070", ready for terra::rast(crs = ...)
/// ```
public enum CoordinateReferenceSystem: Sendable, Hashable, Codable {
    /// Longitude and latitude in degrees: EPSG:4326 (WGS 84) or EPSG:4269 (NAD83).
    case geographic(epsg: Int)
    /// Grid coordinates in metres from a map projection, with its EPSG code if it has one.
    case projected(MapProjection, epsg: Int?)

    /// WGS 84 longitude and latitude, EPSG:4326.
    public static let wgs84 = CoordinateReferenceSystem.geographic(epsg: 4326)

    /// The geographic EPSG codes a raster may use: WGS 84 (4326) and NAD83 (4269).
    public static let geographicEPSGCodes: Set<Int> = [4326, 4269]

    /// The system with an EPSG code.
    ///
    /// Recognised codes are 4326 and 4269; WGS 84, NAD83, NAD83(2011) and ETRS89 UTM zones (326xx, 327xx,
    /// 269xx, 63xx, 258xx); and the NAD83 Albers systems for the conterminous US (5070, 5071, 5072, 6350),
    /// Alaska (3338, 6393), California (3310) and British Columbia (3005).
    ///
    /// - Parameter epsg: The EPSG code.
    /// - Returns: The system, or `nil` if the code isn't one of those.
    public init?(epsg: Int) {
        if Self.geographicEPSGCodes.contains(epsg) {
            self = .geographic(epsg: epsg)
        } else if let projection = MapProjection(epsg: epsg) {
            self = .projected(projection, epsg: epsg)
        } else {
            return nil
        }
    }

    /// The system's EPSG code, or `nil` for a projection that has none.
    public var epsg: Int? {
        switch self {
        case .geographic(let epsg): epsg
        case .projected(_, let epsg): epsg
        }
    }

    /// The map projection, or `nil` for longitude and latitude.
    public var projection: MapProjection? {
        if case .projected(let projection, _) = self { return projection }
        return nil
    }

    /// Whether coordinates are longitude and latitude in degrees, rather than metres.
    public var isGeographic: Bool { projection == nil }

    /// The definition R's `terra` and `sf` accept as a `crs`: `"EPSG:5070"`, or a PROJ string for a
    /// projection without an EPSG code.
    public var definition: String {
        switch self {
        case .geographic(let epsg): "EPSG:\(epsg)"
        case .projected(let projection, let epsg): epsg.map { "EPSG:\($0)" } ?? projection.projDefinition
        }
    }

    // MARK: - Converting coordinates

    /// Grid coordinates of a longitude and latitude.
    ///
    /// - Parameters:
    ///   - longitude: The longitude, in degrees.
    ///   - latitude: The latitude, in degrees.
    /// - Returns: The coordinates in this system's units, or `nil` if the point can't be projected.
    public func coordinates(longitude: Double, latitude: Double) -> (x: Double, y: Double)? {
        guard let projection else { return (longitude, latitude) }
        return projection.project(longitude: longitude, latitude: latitude)
    }

    /// The longitude and latitude of grid coordinates.
    ///
    /// - Parameters:
    ///   - x: The x coordinate in this system's units.
    ///   - y: The y coordinate in this system's units.
    /// - Returns: The longitude and latitude in degrees, or `nil` if the point is off the map.
    public func geographic(x: Double, y: Double) -> (longitude: Double, latitude: Double)? {
        guard let projection else { return (x, y) }
        return projection.unproject(x: x, y: y)
    }

    /// The smallest extent in this system enclosing a longitude/latitude area.
    ///
    /// A projected area's edges curve, so the edges are sampled and the extremes taken. The extremes of a
    /// Transverse Mercator or Albers image of a rectangle always lie on its edges.
    ///
    /// - Parameter area: The area.
    /// - Returns: The enclosing extent, or `nil` if part of the area can't be projected.
    public func extent(enclosing area: GeographicBounds) -> RasterExtent? {
        guard projection != nil else { return RasterExtent(area) }
        let points = Self.edgePoints(west: area.west, east: area.east, south: area.south, north: area.north)
            .map { coordinates(longitude: $0.0, latitude: $0.1) }
        guard points.allSatisfy({ $0 != nil }) else { return nil }
        let xs = points.map { $0!.x }
        let ys = points.map { $0!.y }
        return RasterExtent(west: xs.min()!, east: xs.max()!, south: ys.min()!, north: ys.max()!)
    }

    /// The smallest longitude/latitude area enclosing an extent in this system.
    ///
    /// - Parameter extent: The extent.
    /// - Returns: The enclosing area, or `nil` if part of the extent is off the map.
    public func geographicBounds(enclosing extent: RasterExtent) -> GeographicBounds? {
        guard projection != nil else {
            return GeographicBounds(west: extent.west, east: extent.east, south: extent.south, north: extent.north)
        }
        let points = Self.edgePoints(west: extent.west, east: extent.east, south: extent.south, north: extent.north)
            .map { geographic(x: $0.0, y: $0.1) }
        guard points.allSatisfy({ $0 != nil }) else { return nil }
        return GeographicBounds(longitudes: points.map { $0!.longitude }, latitudes: points.map { $0!.latitude })
    }

    /// Points along the four edges of a rectangle, 64 intervals per edge.
    private static func edgePoints(west: Double, east: Double, south: Double, north: Double) -> [(Double, Double)] {
        let steps = 64
        return (0 ... steps).flatMap { step -> [(Double, Double)] in
            let t = Double(step) / Double(steps)
            let x = west + t * (east - west)
            let y = south + t * (north - south)
            return [(x, south), (x, north), (west, y), (east, y)]
        }
    }
}
