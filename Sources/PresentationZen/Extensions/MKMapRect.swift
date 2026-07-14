//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  MKMapRect.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 10/27/21.
//

import Foundation
import MapKit

extension MKMapRect {


    /// Converts an `MKCoordinateRegion` to an `MKMapRect` in map-point space.
    ///
    /// - Parameter region: The coordinate region to convert.
    /// - Returns: An `MKMapRect` covering the same geographic area.
    static public func fromCoordinateRegion(region: MKCoordinateRegion) -> MKMapRect {

        let topLeft = CLLocationCoordinate2D( latitude: region.center.latitude + (region.span.latitudeDelta/2),
                                              longitude: region.center.longitude - (region.span.longitudeDelta/2))

        let bottomRight = CLLocationCoordinate2D( latitude: region.center.latitude - (region.span.latitudeDelta/2),
                                                  longitude: region.center.longitude + (region.span.longitudeDelta/2))

        let a = MKMapPoint(topLeft)
        let b = MKMapPoint(bottomRight)

        return MKMapRect(origin: MKMapPoint( x: min(a.x,b.x),
                                             y: min(a.y,b.y)),
                         size: MKMapSize( width: abs(a.x-b.x),
                                          height: abs(a.y-b.y)))
    }

}
