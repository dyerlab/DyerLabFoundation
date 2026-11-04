//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Ellipsoid.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The reference ellipsoid a map projection is computed on.
///
/// WGS 84 and GRS 80 differ by about 0.1 mm in the polar radius, so they give the same projected coordinates
/// to well under a millimetre. Both are kept so a raster's coordinate system is described exactly.
public struct Ellipsoid: Sendable, Hashable, Codable {
    /// The equatorial radius, in metres.
    public let semiMajorAxis: Double
    /// The reciprocal of the flattening, 1/f.
    public let inverseFlattening: Double

    /// Creates an ellipsoid.
    ///
    /// - Parameters:
    ///   - semiMajorAxis: The equatorial radius, in metres.
    ///   - inverseFlattening: The reciprocal of the flattening, 1/f.
    /// - Returns: `nil` unless both values are finite and positive and the flattening is less than 1.
    public init?(semiMajorAxis: Double, inverseFlattening: Double) {
        guard semiMajorAxis.isFinite, semiMajorAxis > 0, inverseFlattening.isFinite, inverseFlattening > 1 else {
            return nil
        }
        self.semiMajorAxis = semiMajorAxis
        self.inverseFlattening = inverseFlattening
    }

    /// WGS 84, used by GPS and by EPSG:4326.
    public static let wgs84 = Ellipsoid(semiMajorAxis: 6_378_137, inverseFlattening: 298.257223563)!

    /// GRS 80, used by NAD83 and ETRS89.
    public static let grs80 = Ellipsoid(semiMajorAxis: 6_378_137, inverseFlattening: 298.257222101)!

    /// The flattening, f.
    public var flattening: Double { 1 / inverseFlattening }

    /// The first eccentricity, e.
    public var eccentricity: Double { (flattening * (2 - flattening)).squareRoot() }

    /// The PROJ name of this ellipsoid (`WGS84` or `GRS80`), or `nil` if it's neither.
    var projName: String? {
        switch self {
        case .wgs84: "WGS84"
        case .grs80: "GRS80"
        default: nil
        }
    }
}
