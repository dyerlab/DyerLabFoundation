//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RasterExtent.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// A rectangle in a raster's own coordinates: degrees for a geographic raster, metres for a projected one.
///
/// The edge names follow the grid: `west` is the smallest x, `north` the largest y.
public struct RasterExtent: Sendable, Hashable, Codable {
    /// The smallest x coordinate.
    public let west: Double
    /// The largest x coordinate.
    public let east: Double
    /// The smallest y coordinate.
    public let south: Double
    /// The largest y coordinate.
    public let north: Double

    /// Creates an extent.
    ///
    /// - Parameters:
    ///   - west: The smallest x coordinate.
    ///   - east: The largest x coordinate.
    ///   - south: The smallest y coordinate.
    ///   - north: The largest y coordinate.
    /// - Returns: `nil` unless every edge is finite, `west < east` and `south < north`.
    public init?(west: Double, east: Double, south: Double, north: Double) {
        guard [west, east, south, north].allSatisfy(\.isFinite), west < east, south < north else { return nil }
        self.west = west
        self.east = east
        self.south = south
        self.north = north
    }

    /// The extent of a longitude/latitude area, in degrees.
    ///
    /// - Parameter bounds: The area.
    public init(_ bounds: GeographicBounds) {
        west = bounds.west
        east = bounds.east
        south = bounds.south
        north = bounds.north
    }

    /// The east–west size.
    public var width: Double { east - west }

    /// The north–south size.
    public var height: Double { north - south }

    /// The overlap with another extent, or `nil` if they don't overlap.
    ///
    /// - Parameter other: Another extent in the same coordinates.
    public func intersection(_ other: RasterExtent) -> RasterExtent? {
        RasterExtent(west: max(west, other.west), east: min(east, other.east),
                     south: max(south, other.south), north: min(north, other.north))
    }

    /// Whether a point lies inside or on the edge of the extent.
    ///
    /// - Parameters:
    ///   - x: The point's x coordinate.
    ///   - y: The point's y coordinate.
    public func contains(x: Double, y: Double) -> Bool {
        x >= west && x <= east && y >= south && y <= north
    }
}
