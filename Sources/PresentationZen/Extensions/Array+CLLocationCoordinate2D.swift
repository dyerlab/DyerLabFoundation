//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  Array+CLLocationCoordinate2D.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 5/30/25.
//

import Foundation
import CoreLocation

public extension Array where Element == CLLocationCoordinate2D {

    /// Returns the bounding box of the coordinate array as (minLon, maxLon, minLat, maxLat).
    ///
    /// Returns `(NaN, NaN, NaN, NaN)` when the array is empty.
    ///
    /// - Returns: A 4-element tuple `(minLon, maxLon, minLat, maxLat)`.
    func bounds() -> (Double, Double, Double, Double) {

        guard !self.isEmpty else {
            return (Double.nan, Double.nan, Double.nan, Double.nan)
        }

        var maxLat: Double = -200;
        var maxLon: Double = -200;
        var minLat: Double = 200;
        var minLon: Double = 200;

        for location in self {
            if location.latitude < minLat {
                minLat = location.latitude;
            }
            if location.longitude < minLon {
                minLon = location.longitude;
            }
            if location.latitude > maxLat {
                maxLat = location.latitude;
            }
            if location.longitude > maxLon {
                maxLon = location.longitude;
            }
        }
        return (minLon, maxLon, minLat, maxLat )
    }

    /// Returns the centroid of the values
    /// - Returns: A `CLLocationCoordinate2D` representing the center of the array of values.
    var center: CLLocationCoordinate2D? {
        guard !self.isEmpty else { return nil }
        let range = self.bounds()
        return CLLocationCoordinate2DMake( CLLocationDegrees( ( range.2 + range.3 ) * 0.5),
                                           CLLocationDegrees( ( range.0 + range.1 ) * 0.5) );
    }




}
