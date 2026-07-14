//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  MKCoordianteRegion.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 2/10/18.
//

import CoreLocation
import Foundation
import MapKit

public extension MKCoordinateRegion {


    /// Creates the smallest `MKCoordinateRegion` that contains all supplied coordinates.
    ///
    /// Handles antimeridian-spanning datasets by comparing a prime-meridian-centred region
    /// with a 180th-meridian-centred region and choosing the one with the smaller longitude span.
    ///
    /// - Parameter coordinates: The coordinates to fit. Returns `nil` when the array is empty.
    init?(coordinates: [CLLocationCoordinate2D]) {

        // first create a region centered around the prime meridian
        let primeRegion = MKCoordinateRegion.region(for: coordinates, transform: { $0 }, inverseTransform: { $0 })

        // next create a region centered around the 180th meridian
        let transformedRegion = MKCoordinateRegion.region(for: coordinates, transform: MKCoordinateRegion.transform, inverseTransform: MKCoordinateRegion.inverseTransform)

        // return the region that has the smallest longitude delta
        if let a = primeRegion,
            let b = transformedRegion,
            let min = [a, b].min(by: { $0.span.longitudeDelta < $1.span.longitudeDelta }) {
            self = min
        }

        else if let a = primeRegion {
            self = a
        }

        else if let b = transformedRegion {
            self = b
        }

        else {
            return nil
        }
    }

    // Latitude -180...180 -> 0...360
    private static func transform(c: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        if c.longitude < 0 { return CLLocationCoordinate2DMake(c.latitude, 360 + c.longitude) }
        return c
    }

    // Latitude 0...360 -> -180...180
    private static func inverseTransform(c: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        if c.longitude > 180 { return CLLocationCoordinate2DMake(c.latitude, -360 + c.longitude) }
        return c
    }

    private typealias Transform = (CLLocationCoordinate2D) -> (CLLocationCoordinate2D)

    private static func region(for coordinates: [CLLocationCoordinate2D], transform: Transform, inverseTransform: Transform) -> MKCoordinateRegion? {

        // handle empty array
        guard !coordinates.isEmpty else { return nil }

        // handle single coordinate
        guard coordinates.count > 1 else {
            return MKCoordinateRegion(center: coordinates[0], span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1))
        }

        let transformed = coordinates.map(transform)

        // find the span
        let minLat = transformed.min { $0.latitude < $1.latitude }!.latitude
        let maxLat = transformed.max { $0.latitude < $1.latitude }!.latitude
        let minLon = transformed.min { $0.longitude < $1.longitude }!.longitude
        let maxLon = transformed.max { $0.longitude < $1.longitude }!.longitude
        let span = MKCoordinateSpan(latitudeDelta: maxLat - minLat, longitudeDelta: maxLon - minLon)

        // find the center of the span
        let center = inverseTransform( CLLocationCoordinate2DMake( (maxLat - span.latitudeDelta / 2),
                                                                 maxLon - span.longitudeDelta / 2) )

        return MKCoordinateRegion(center: center, span: span)
    }

    /// Returns a copy of this region with both span dimensions multiplied by `scale`.
    ///
    /// - Parameter scale: The factor by which to enlarge (> 1) or shrink (< 1) the span.
    /// - Returns: A new `MKCoordinateRegion` with the scaled span and the same centre.
    func withBuffer(scale: CGFloat) -> MKCoordinateRegion {
        var span = self.span
        span.latitudeDelta = span.latitudeDelta * scale
        span.longitudeDelta = span.longitudeDelta * scale
        return MKCoordinateRegion(center: self.center, span: span)
    }
}
