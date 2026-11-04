//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GeographicBounds.swift
//  Matrix
//
//  Plain longitude/latitude doubles rather than CoreLocation types, so a
//  raster's extent and a study area's crop box live in Matrix without pulling
//  in CoreLocation. Graph builds one from its node coordinates.
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// A longitude/latitude bounding box, in decimal degrees.
///
/// Bounds never cross the antimeridian: `west` is always less than or equal to `east`.
public struct GeographicBounds: Sendable, Equatable, Hashable, Codable {
    /// The western edge, in degrees longitude (−180 to 180).
    public let west: Double
    /// The eastern edge, in degrees longitude (−180 to 180).
    public let east: Double
    /// The southern edge, in degrees latitude (−90 to 90).
    public let south: Double
    /// The northern edge, in degrees latitude (−90 to 90).
    public let north: Double

    /// Creates bounds from their four edges.
    ///
    /// - Parameters:
    ///   - west: The western edge, in degrees longitude.
    ///   - east: The eastern edge, in degrees longitude.
    ///   - south: The southern edge, in degrees latitude.
    ///   - north: The northern edge, in degrees latitude.
    /// - Returns: `nil` if an edge isn't finite, is out of range, or `west > east` or `south > north`.
    public init?(west: Double, east: Double, south: Double, north: Double) {
        guard [west, east, south, north].allSatisfy(\.isFinite),
              west >= -180, east <= 180, south >= -90, north <= 90,
              west <= east, south <= north else { return nil }
        self.west = west
        self.east = east
        self.south = south
        self.north = north
    }

    /// Creates the smallest bounds enclosing a set of points.
    ///
    /// A single point gives zero-sized bounds; use ``buffered(by:minimum:)`` to widen them.
    ///
    /// - Parameters:
    ///   - longitudes: Each point's longitude, in degrees.
    ///   - latitudes: Each point's latitude, in degrees, in the same order.
    /// - Returns: `nil` if there are no points, the arrays differ in length, or a coordinate is out of range.
    public init?(longitudes: [Double], latitudes: [Double]) {
        guard !longitudes.isEmpty, longitudes.count == latitudes.count,
              let west = longitudes.min(), let east = longitudes.max(),
              let south = latitudes.min(), let north = latitudes.max() else { return nil }
        self.init(west: west, east: east, south: south, north: north)
    }

    /// The east–west extent, in degrees.
    public var width: Double { east - west }

    /// The north–south extent, in degrees.
    public var height: Double { north - south }

    /// Bounds widened on every side, clamped to the valid longitude and latitude range.
    ///
    /// Each side moves out by `fraction` of the box's width (east and west) or height (north and south),
    /// but never by less than `minimum` degrees, so a very small or single-point study area still gets
    /// some surrounding landscape.
    ///
    /// - Parameters:
    ///   - fraction: The buffer as a fraction of each dimension (default `0.1`, i.e. 10%).
    ///   - minimum: The smallest buffer on any side, in degrees (default `0.01`, about 1 km).
    /// - Returns: The widened bounds.
    public func buffered(by fraction: Double = 0.1, minimum: Double = 0.01) -> GeographicBounds {
        let dx = max(width * fraction, minimum)
        let dy = max(height * fraction, minimum)
        // The clamped edges are always in range and ordered, so the initializer can't fail.
        return GeographicBounds(west: max(west - dx, -180), east: min(east + dx, 180),
                                south: max(south - dy, -90), north: min(north + dy, 90))!
    }

    /// The overlap of these bounds with `other`.
    ///
    /// - Parameter other: The bounds to intersect with.
    /// - Returns: The overlapping bounds, or `nil` if they don't overlap with a positive area.
    public func intersection(_ other: GeographicBounds) -> GeographicBounds? {
        let west = max(self.west, other.west)
        let east = min(self.east, other.east)
        let south = max(self.south, other.south)
        let north = min(self.north, other.north)
        guard west < east, south < north else { return nil }
        return GeographicBounds(west: west, east: east, south: south, north: north)
    }

    /// Whether a point lies inside these bounds, edges included.
    ///
    /// - Parameters:
    ///   - longitude: The point's longitude, in degrees.
    ///   - latitude: The point's latitude, in degrees.
    /// - Returns: `true` if the point is inside or on an edge.
    public func contains(longitude: Double, latitude: Double) -> Bool {
        longitude >= west && longitude <= east && latitude >= south && latitude <= north
    }
}
