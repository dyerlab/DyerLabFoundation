//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  SpatialUtilitiesTests.swift
//  PresentationZenTests
//
//  Ported from PopulationGenetics' SpatialTests.swift: ConvexHull,
//  DistanceBetween, the CLLocationCoordinate2D array helpers, and the
//  MKCoordinateRegion / MKMapRect builders. The MapPlacard section of the
//  original file is domain-specific (PopulationGenetics' own type) and
//  stays there.
//
//  Created by Rodney Dyer on 2026.07.14.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
import CoreLocation
import MapKit
@testable import PresentationZen

struct SpatialUtilitiesTests {

    /// Coordinate equality helper. Values pass through the routines unchanged,
    /// so an exact comparison is appropriate here.
    private func sameCoordinate(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        a.latitude == b.latitude && a.longitude == b.longitude
    }

    private func contains(_ hull: [CLLocationCoordinate2D], _ point: CLLocationCoordinate2D) -> Bool {
        hull.contains { sameCoordinate($0, point) }
    }

    // MARK: - ConvexHull

    @Test func convexHullOfSquareExcludesInteriorPoint() async throws {
        let corners = [
            CLLocationCoordinate2D(latitude: 0,  longitude: 0),
            CLLocationCoordinate2D(latitude: 0,  longitude: 10),
            CLLocationCoordinate2D(latitude: 10, longitude: 10),
            CLLocationCoordinate2D(latitude: 10, longitude: 0),
        ]
        let interior = CLLocationCoordinate2D(latitude: 5, longitude: 5)

        let hull = ConvexHull(pts: corners + [interior])

        // Only the four corners should make up the hull.
        #expect(hull.convexHull.count == 4)
        for corner in corners {
            #expect(contains(hull.convexHull, corner))
        }
        #expect(!contains(hull.convexHull, interior))
    }

    @Test func convexHullOfTriangleKeepsAllVertices() async throws {
        let triangle = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 4),
            CLLocationCoordinate2D(latitude: 3, longitude: 2),
        ]

        let hull = ConvexHull(pts: triangle)

        #expect(hull.convexHull.count == 3)
        for vertex in triangle {
            #expect(contains(hull.convexHull, vertex))
        }
    }

    @Test func convexHullRequiresAtLeastThreePoints() async throws {
        let twoPoints = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
        ]

        let hull = ConvexHull(pts: twoPoints)

        // With fewer than three points the hull is left empty.
        #expect(hull.convexHull.isEmpty)
    }

    @Test func convexHullPolygonMatchesPointCount() async throws {
        let pts = [
            CLLocationCoordinate2D(latitude: 0,  longitude: 0),
            CLLocationCoordinate2D(latitude: 0,  longitude: 6),
            CLLocationCoordinate2D(latitude: 6,  longitude: 6),
            CLLocationCoordinate2D(latitude: 6,  longitude: 0),
        ]

        let hull = ConvexHull(pts: pts)

        #expect(hull.polygon.pointCount == hull.convexHull.count)
    }

    /// Regression guard for the leftmost-index tie-break: when two points share
    /// the minimum longitude, the southern one (smaller latitude) must anchor the
    /// march so that both vertical-edge endpoints land on the hull.
    @Test func convexHullHandlesSharedMinimumLongitude() async throws {
        let pts = [
            CLLocationCoordinate2D(latitude: 0,  longitude: 0),   // shares min longitude
            CLLocationCoordinate2D(latitude: 10, longitude: 0),   // shares min longitude
            CLLocationCoordinate2D(latitude: 5,  longitude: 10),
        ]

        let hull = ConvexHull(pts: pts)

        #expect(hull.convexHull.count == 3)
        for vertex in pts {
            #expect(contains(hull.convexHull, vertex))
        }
    }

    // MARK: - DistanceBetween

    @Test func distanceBetweenIdenticalCoordinatesIsZero() async throws {
        let point = CLLocationCoordinate2D(latitude: 37.5407, longitude: -77.4360)
        #expect(distanceBetween(point, point) < 0.0001)
    }

    @Test func distanceBetweenOneDegreeAtEquator() async throws {
        let a = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let b = CLLocationCoordinate2D(latitude: 0, longitude: 1)

        // One degree of longitude at the equator is ~111 km.
        let distance = distanceBetween(a, b)
        #expect(distance > 100 && distance < 120)
    }

    @Test func distanceBetweenIsSymmetric() async throws {
        let a = CLLocationCoordinate2D(latitude: 37.0, longitude: -77.0)
        let b = CLLocationCoordinate2D(latitude: 38.0, longitude: -78.0)

        #expect(distanceBetween(a, b) == distanceBetween(b, a))
    }

    // MARK: - Array<CLLocationCoordinate2D> bounds & center

    @Test func coordinateBounds() async throws {
        let coords = [
            CLLocationCoordinate2D(latitude: 10,  longitude: 20),
            CLLocationCoordinate2D(latitude: 30,  longitude: 40),
            CLLocationCoordinate2D(latitude: -5,  longitude: 0),
        ]

        let (minLon, maxLon, minLat, maxLat) = coords.bounds()
        #expect(minLon == 0)
        #expect(maxLon == 40)
        #expect(minLat == -5)
        #expect(maxLat == 30)
    }

    @Test func coordinateBoundsEmptyIsNaN() async throws {
        let coords: [CLLocationCoordinate2D] = []
        let (minLon, maxLon, minLat, maxLat) = coords.bounds()
        #expect(minLon.isNaN)
        #expect(maxLon.isNaN)
        #expect(minLat.isNaN)
        #expect(maxLat.isNaN)
    }

    @Test func coordinateCenter() async throws {
        let coords = [
            CLLocationCoordinate2D(latitude: 10,  longitude: 20),
            CLLocationCoordinate2D(latitude: 30,  longitude: 40),
            CLLocationCoordinate2D(latitude: -5,  longitude: 0),
        ]

        let center = try #require(coords.center)
        #expect(center.latitude == 12.5)   // (-5 + 30) / 2
        #expect(center.longitude == 20.0)  // (0 + 40) / 2
    }

    @Test func coordinateCenterEmptyIsNil() async throws {
        let coords: [CLLocationCoordinate2D] = []
        #expect(coords.center == nil)
    }

    // MARK: - MKCoordinateRegion(coordinates:)

    @Test func regionFromEmptyCoordinatesIsNil() async throws {
        let region = MKCoordinateRegion(coordinates: [])
        #expect(region == nil)
    }

    @Test func regionFromSingleCoordinate() async throws {
        let coord = CLLocationCoordinate2D(latitude: 37.5, longitude: -77.4)
        let region = try #require(MKCoordinateRegion(coordinates: [coord]))

        #expect(region.center.latitude == coord.latitude)
        #expect(region.center.longitude == coord.longitude)
        // A lone point is given a default 1x1 degree span.
        #expect(region.span.latitudeDelta == 1)
        #expect(region.span.longitudeDelta == 1)
    }

    @Test func regionFromMultipleCoordinatesCoversRange() async throws {
        let coords = [
            CLLocationCoordinate2D(latitude: 10, longitude: 20),
            CLLocationCoordinate2D(latitude: 30, longitude: 40),
        ]
        let region = try #require(MKCoordinateRegion(coordinates: coords))

        // Center sits between the extremes and the span spans them.
        #expect(region.center.latitude == 20)
        #expect(region.center.longitude == 30)
        #expect(region.span.latitudeDelta == 20)
        #expect(region.span.longitudeDelta == 20)
    }

    @Test func regionWithBufferScalesSpan() async throws {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 4)
        )

        let buffered = region.withBuffer(scale: 2.0)
        #expect(buffered.span.latitudeDelta == 4)
        #expect(buffered.span.longitudeDelta == 8)
        // Center is unchanged by buffering.
        #expect(buffered.center.latitude == region.center.latitude)
        #expect(buffered.center.longitude == region.center.longitude)
    }

    // MARK: - MKMapRect.fromCoordinateRegion

    @Test func mapRectFromRegionHasPositiveArea() async throws {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.5, longitude: -77.4),
            span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
        )

        let rect = MKMapRect.fromCoordinateRegion(region: region)
        #expect(rect.size.width > 0)
        #expect(rect.size.height > 0)
        #expect(!rect.isNull)
    }
}
