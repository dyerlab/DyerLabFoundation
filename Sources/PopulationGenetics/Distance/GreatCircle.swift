//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GreatCircle.swift
//  PopulationGenetics
//
//  The great-circle distance between two coordinates, by the haversine
//  formula on a sphere of radius 6371 km, written as gstudio's
//  `strata_distance(mode = "Circle")` writes it so the two agree to rounding.
//  `CLLocation.distance(from:)`, which `distanceBetween` uses, follows a
//  model Apple doesn't document, so it isn't used where R must agree.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import CoreLocation

/// Great-circle distances on a spherical Earth.
public enum GreatCircle {

    /// The Earth's radius, in kilometres, as gstudio uses it.
    public static let earthRadius = 6371.0

    /// The great-circle distance between two coordinates, by the haversine formula.
    ///
    /// - Parameters:
    ///   - first: One coordinate, in decimal degrees.
    ///   - second: The other coordinate, in decimal degrees.
    /// - Returns: The distance in kilometres.
    public static func distance(_ first: CLLocationCoordinate2D, _ second: CLLocationCoordinate2D) -> Double {
        let radians = Double.pi / 180
        let a = sin(0.5 * (second.latitude - first.latitude) * radians)
        let b = sin(0.5 * (second.longitude - first.longitude) * radians)
        let h = a * a + cos(first.latitude * radians) * cos(second.latitude * radians) * b * b
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }
}
