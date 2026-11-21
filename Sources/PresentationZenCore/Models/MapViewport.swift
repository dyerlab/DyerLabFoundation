//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MapViewport.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.10.23.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import MapKit

/// What the map is currently showing: its visible area and its scale.
public struct MapViewport: Sendable {

    /// The visible area of the map.
    public let rect: MKMapRect

    /// How many metres one screen point covers at the centre of the map.
    public let metersPerPoint: Double

    /// Captures a viewport from a camera change.
    ///
    /// - Parameters:
    ///   - rect: The visible area of the map.
    ///   - width: The map's width on screen, in points.
    public init(rect: MKMapRect, width: Double) {
        self.rect = rect
        let centreLatitude = MKMapPoint(x: rect.midX, y: rect.midY).coordinate.latitude
        metersPerPoint = rect.size.width * MKMetersPerMapPointAtLatitude(centreLatitude) / max(width, 1)
    }
}
