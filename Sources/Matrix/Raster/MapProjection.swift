//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MapProjection.swift
//  Matrix
//
//  The two projections rasters may arrive in, written out here rather than
//  linking PROJ: Transverse Mercator (every UTM zone) and Albers equal-area
//  conic (NLCD's CONUS Albers, EPSG:5070, and its relatives). The formulas are
//  in MapProjection+TransverseMercator.swift and +AlbersEqualArea.swift; both
//  match PROJ to well under a millimetre.
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// A map projection between longitude/latitude and grid coordinates in metres.
///
/// Two methods are supported: Transverse Mercator, which includes every UTM zone, and Albers equal-area conic,
/// the projection NLCD land cover is distributed in.
///
/// ```swift
/// let utm = MapProjection.utm(zone: 12)!
/// let point = utm.project(longitude: -111.5, latitude: 29.0)   // (x: 451_299.7, y: 3_208_088.6)
/// ```
public struct MapProjection: Sendable, Hashable, Codable {

    /// How longitude and latitude are mapped onto the plane.
    public enum Method: String, Sendable, Hashable, Codable {
        /// Transverse Mercator: conformal, true to scale (times ``MapProjection/scaleFactor``) along the
        /// central meridian. UTM zones are Transverse Mercator.
        case transverseMercator
        /// Albers equal-area conic: preserves area, true to scale along the two standard parallels.
        case albersEqualArea
    }

    /// The projection method.
    public let method: Method
    /// The ellipsoid the projection is computed on.
    public let ellipsoid: Ellipsoid
    /// The latitude of the grid origin, in degrees.
    public let latitudeOfOrigin: Double
    /// The longitude of the grid origin (the central meridian), in degrees.
    public let centralMeridian: Double
    /// The first standard parallel, in degrees (Albers only; 0 for Transverse Mercator).
    public let standardParallel1: Double
    /// The second standard parallel, in degrees (Albers only; 0 for Transverse Mercator).
    public let standardParallel2: Double
    /// The scale along the central meridian (Transverse Mercator only; 1 for Albers).
    public let scaleFactor: Double
    /// The x coordinate of the origin, in metres.
    public let falseEasting: Double
    /// The y coordinate of the origin, in metres.
    public let falseNorthing: Double

    // MARK: - Initialization

    /// Creates a Transverse Mercator projection.
    ///
    /// - Parameters:
    ///   - ellipsoid: The ellipsoid.
    ///   - latitudeOfOrigin: The latitude of the origin, in degrees.
    ///   - centralMeridian: The central meridian, in degrees.
    ///   - scaleFactor: The scale along the central meridian.
    ///   - falseEasting: The x coordinate of the origin, in metres.
    ///   - falseNorthing: The y coordinate of the origin, in metres.
    /// - Returns: `nil` if a latitude or longitude is out of range, the scale isn't positive, or a value isn't finite.
    public init?(transverseMercatorOn ellipsoid: Ellipsoid,
                 latitudeOfOrigin: Double,
                 centralMeridian: Double,
                 scaleFactor: Double,
                 falseEasting: Double,
                 falseNorthing: Double) {
        guard abs(latitudeOfOrigin) < 90, abs(centralMeridian) <= 180, scaleFactor > 0,
              [scaleFactor, falseEasting, falseNorthing].allSatisfy(\.isFinite) else { return nil }
        method = .transverseMercator
        self.ellipsoid = ellipsoid
        self.latitudeOfOrigin = latitudeOfOrigin
        self.centralMeridian = centralMeridian
        standardParallel1 = 0
        standardParallel2 = 0
        self.scaleFactor = scaleFactor
        self.falseEasting = falseEasting
        self.falseNorthing = falseNorthing
    }

    /// Creates an Albers equal-area conic projection.
    ///
    /// - Parameters:
    ///   - ellipsoid: The ellipsoid.
    ///   - latitudeOfOrigin: The latitude of the origin, in degrees.
    ///   - centralMeridian: The central meridian, in degrees.
    ///   - standardParallel1: The first standard parallel, in degrees.
    ///   - standardParallel2: The second standard parallel, in degrees.
    ///   - falseEasting: The x coordinate of the origin, in metres.
    ///   - falseNorthing: The y coordinate of the origin, in metres.
    /// - Returns: `nil` if a latitude or longitude is out of range, the standard parallels are symmetric about
    ///   the equator (which makes the cone a cylinder), or a value isn't finite.
    public init?(albersEqualAreaOn ellipsoid: Ellipsoid,
                 latitudeOfOrigin: Double,
                 centralMeridian: Double,
                 standardParallel1: Double,
                 standardParallel2: Double,
                 falseEasting: Double,
                 falseNorthing: Double) {
        guard abs(latitudeOfOrigin) < 90, abs(centralMeridian) <= 180,
              abs(standardParallel1) < 90, abs(standardParallel2) < 90,
              abs(standardParallel1 + standardParallel2) > 1e-10,
              falseEasting.isFinite, falseNorthing.isFinite else { return nil }
        method = .albersEqualArea
        self.ellipsoid = ellipsoid
        self.latitudeOfOrigin = latitudeOfOrigin
        self.centralMeridian = centralMeridian
        self.standardParallel1 = standardParallel1
        self.standardParallel2 = standardParallel2
        scaleFactor = 1
        self.falseEasting = falseEasting
        self.falseNorthing = falseNorthing
    }

    /// A Universal Transverse Mercator zone.
    ///
    /// - Parameters:
    ///   - zone: The zone, 1 to 60. Zone 1 is centred on 177° W, and each zone is 6° wide.
    ///   - southern: `true` for the southern-hemisphere zone, which adds a 10,000 km false northing
    ///     (default `false`).
    ///   - ellipsoid: The ellipsoid (default WGS 84; NAD83 and ETRS89 zones use GRS 80).
    /// - Returns: The zone's projection, or `nil` if `zone` is out of range.
    public static func utm(zone: Int, southern: Bool = false, ellipsoid: Ellipsoid = .wgs84) -> MapProjection? {
        guard (1 ... 60).contains(zone) else { return nil }
        return MapProjection(transverseMercatorOn: ellipsoid, latitudeOfOrigin: 0,
                             centralMeridian: Double(zone) * 6 - 183, scaleFactor: 0.9996,
                             falseEasting: 500_000, falseNorthing: southern ? 10_000_000 : 0)
    }

    // MARK: - Projecting

    /// Projects a longitude and latitude onto the grid.
    ///
    /// - Parameters:
    ///   - longitude: The longitude, in degrees.
    ///   - latitude: The latitude, in degrees.
    /// - Returns: The grid coordinates in metres, or `nil` if the point can't be projected (more than 90° of
    ///   longitude from a Transverse Mercator central meridian, or a latitude beyond ±90°).
    public func project(longitude: Double, latitude: Double) -> (x: Double, y: Double)? {
        guard longitude.isFinite, abs(latitude) <= 90 else { return nil }
        switch method {
        case .transverseMercator: return transverseMercatorForward(longitude: longitude, latitude: latitude)
        case .albersEqualArea: return albersForward(longitude: longitude, latitude: latitude)
        }
    }

    /// Finds the longitude and latitude of a grid point.
    ///
    /// - Parameters:
    ///   - x: The x (easting) coordinate, in metres.
    ///   - y: The y (northing) coordinate, in metres.
    /// - Returns: The longitude and latitude in degrees, or `nil` if the point is off the projection's map.
    public func unproject(x: Double, y: Double) -> (longitude: Double, latitude: Double)? {
        guard x.isFinite, y.isFinite else { return nil }
        switch method {
        case .transverseMercator: return transverseMercatorInverse(x: x, y: y)
        case .albersEqualArea: return albersInverse(x: x, y: y)
        }
    }

    /// The PROJ definition of this projection, which R's `terra` and `sf` accept as a `crs`.
    public var projDefinition: String {
        func number(_ value: Double) -> String {
            value == value.rounded() && abs(value) < 1e15 ? String(Int(value)) : String(value)
        }
        let ellipsoidTerm = ellipsoid.projName.map { "+ellps=\($0)" }
            ?? "+a=\(number(ellipsoid.semiMajorAxis)) +rf=\(number(ellipsoid.inverseFlattening))"
        let parameters: String
        switch method {
        case .transverseMercator:
            parameters = "+proj=tmerc +lat_0=\(number(latitudeOfOrigin)) +lon_0=\(number(centralMeridian)) "
                + "+k=\(number(scaleFactor))"
        case .albersEqualArea:
            parameters = "+proj=aea +lat_0=\(number(latitudeOfOrigin)) +lon_0=\(number(centralMeridian)) "
                + "+lat_1=\(number(standardParallel1)) +lat_2=\(number(standardParallel2))"
        }
        return "\(parameters) +x_0=\(number(falseEasting)) +y_0=\(number(falseNorthing)) \(ellipsoidTerm) "
            + "+units=m +no_defs"
    }

    /// A longitude difference wrapped into −180°…180°, in radians.
    static func wrappedRadians(_ degrees: Double) -> Double {
        var value = degrees.truncatingRemainder(dividingBy: 360)
        if value > 180 { value -= 360 } else if value < -180 { value += 360 }
        return value * .pi / 180
    }
}
