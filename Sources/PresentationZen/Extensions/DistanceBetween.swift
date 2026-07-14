//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  DistanceBetween.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 5/21/25.
//

import Foundation
import CoreLocation

/// Returns the geodesic distance in kilometres between two geographic coordinates.
///
/// Uses `CLLocation.distance(from:)` internally (WGS-84 ellipsoid).
///
/// - Parameters:
///   - coordinate1: The first coordinate.
///   - coordinate2: The second coordinate.
/// - Returns: Distance in kilometres.
public func DistanceBetween(_ coordinate1: CLLocationCoordinate2D, _ coordinate2: CLLocationCoordinate2D) -> Double {
    let location1 = CLLocation(latitude: coordinate1.latitude, longitude: coordinate1.longitude)
    let location2 = CLLocation(latitude: coordinate2.latitude, longitude: coordinate2.longitude)
    return location1.distance(from: location2) / 1000.0 // Distance in kilometers
}
