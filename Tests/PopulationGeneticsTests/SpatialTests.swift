//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2025 The Dyer Laboratory.  All Rights Reserved.
//
//  SpatialTests.swift
// PopulationGenetics
//
//  Created by Claude Code on 6/18/26.
//
//  Coverage for the spatial routines that were re-integrated from the Places
//  package: ConvexHull, DistanceBetween, the CLLocationCoordinate2D array
//  helpers, the MKCoordinateRegion / MKMapRect builders, and MapPlacard.
//

import Foundation
import Testing
import CoreLocation
import MapKit
import PresentationZen
@testable import PopulationGenetics

struct SpatialTests {

    /// Coordinate equality helper. Values pass through the routines unchanged,
    /// so an exact comparison is appropriate here.
    private func sameCoordinate(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        a.latitude == b.latitude && a.longitude == b.longitude
    }

    private func contains(_ hull: [CLLocationCoordinate2D], _ point: CLLocationCoordinate2D) -> Bool {
        hull.contains { sameCoordinate($0, point) }
    }

    // MARK: - ConvexHull

    @Test func testConvexHullOfSquareExcludesInteriorPoint() async throws {
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

    @Test func testConvexHullOfTriangleKeepsAllVertices() async throws {
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

    @Test func testConvexHullRequiresAtLeastThreePoints() async throws {
        let twoPoints = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
        ]

        let hull = ConvexHull(pts: twoPoints)

        // With fewer than three points the hull is left empty.
        #expect(hull.convexHull.isEmpty)
    }

    @Test func testConvexHullPolygonMatchesPointCount() async throws {
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
    @Test func testConvexHullHandlesSharedMinimumLongitude() async throws {
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

    @Test func testDistanceBetweenIdenticalCoordinatesIsZero() async throws {
        let point = CLLocationCoordinate2D(latitude: 37.5407, longitude: -77.4360)
        #expect(DistanceBetween(point, point) < 0.0001)
    }

    @Test func testDistanceBetweenOneDegreeAtEquator() async throws {
        let a = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let b = CLLocationCoordinate2D(latitude: 0, longitude: 1)

        // One degree of longitude at the equator is ~111 km.
        let distance = DistanceBetween(a, b)
        #expect(distance > 100 && distance < 120)
    }

    @Test func testDistanceBetweenIsSymmetric() async throws {
        let a = CLLocationCoordinate2D(latitude: 37.0, longitude: -77.0)
        let b = CLLocationCoordinate2D(latitude: 38.0, longitude: -78.0)

        #expect(DistanceBetween(a, b) == DistanceBetween(b, a))
    }

    // MARK: - Array<CLLocationCoordinate2D> bounds & center

    @Test func testCoordinateBounds() async throws {
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

    @Test func testCoordinateBoundsEmptyIsNaN() async throws {
        let coords: [CLLocationCoordinate2D] = []
        let (minLon, maxLon, minLat, maxLat) = coords.bounds()
        #expect(minLon.isNaN)
        #expect(maxLon.isNaN)
        #expect(minLat.isNaN)
        #expect(maxLat.isNaN)
    }

    @Test func testCoordinateCenter() async throws {
        let coords = [
            CLLocationCoordinate2D(latitude: 10,  longitude: 20),
            CLLocationCoordinate2D(latitude: 30,  longitude: 40),
            CLLocationCoordinate2D(latitude: -5,  longitude: 0),
        ]

        let center = try #require(coords.center)
        #expect(center.latitude == 12.5)   // (-5 + 30) / 2
        #expect(center.longitude == 20.0)  // (0 + 40) / 2
    }

    @Test func testCoordinateCenterEmptyIsNil() async throws {
        let coords: [CLLocationCoordinate2D] = []
        #expect(coords.center == nil)
    }

    // MARK: - MKCoordinateRegion(coordinates:)

    @Test func testRegionFromEmptyCoordinatesIsNil() async throws {
        let region = MKCoordinateRegion(coordinates: [])
        #expect(region == nil)
    }

    @Test func testRegionFromSingleCoordinate() async throws {
        let coord = CLLocationCoordinate2D(latitude: 37.5, longitude: -77.4)
        let region = try #require(MKCoordinateRegion(coordinates: [coord]))

        #expect(region.center.latitude == coord.latitude)
        #expect(region.center.longitude == coord.longitude)
        // A lone point is given a default 1x1 degree span.
        #expect(region.span.latitudeDelta == 1)
        #expect(region.span.longitudeDelta == 1)
    }

    @Test func testRegionFromMultipleCoordinatesCoversRange() async throws {
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

    @Test func testRegionWithBufferScalesSpan() async throws {
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

    @Test func testMapRectFromRegionHasPositiveArea() async throws {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.5, longitude: -77.4),
            span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
        )

        let rect = MKMapRect.fromCoordinateRegion(region: region)
        #expect(rect.size.width > 0)
        #expect(rect.size.height > 0)
        #expect(!rect.isNull)
    }

    // MARK: - MapPlacard equality

    @Test func testMapPlacardEqualsItself() async throws {
        let placard = MapPlacard(
            title: "RVA",
            subtitle: "Richmond",
            coordinate: CLLocationCoordinate2D(latitude: 37.5407, longitude: -77.4360)
        )
        #expect(placard == placard)
    }

    @Test func testMapPlacardsWithSameCoordinateAreEqual() async throws {
        let coord = CLLocationCoordinate2D(latitude: 37.5407, longitude: -77.4360)
        let a = MapPlacard(title: "A", subtitle: "1", coordinate: coord)
        let b = MapPlacard(title: "B", subtitle: "2", coordinate: coord)

        // Different ids, but equality falls through to coordinate comparison.
        #expect(a == b)
    }

    @Test func testMapPlacardsWithDifferentCoordinatesAreNotEqual() async throws {
        let a = MapPlacard(
            title: "A", subtitle: "1",
            coordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -77.0)
        )
        let b = MapPlacard(
            title: "B", subtitle: "2",
            coordinate: CLLocationCoordinate2D(latitude: 38.0, longitude: -78.0)
        )

        #expect(a != b)
    }

    @Test func testMapPlacardsWithSameCoordinateHashEqual() async throws {
        // Hashable's contract requires a == b to imply matching hashes.
        // Equality falls through to coordinate comparison for different ids
        // (see testMapPlacardsWithSameCoordinateAreEqual), so the hash must be
        // coordinate-based too, or Set/Dictionary membership breaks.
        let coord = CLLocationCoordinate2D(latitude: 37.5407, longitude: -77.4360)
        let a = MapPlacard(title: "A", subtitle: "1", coordinate: coord)
        let b = MapPlacard(title: "B", subtitle: "2", coordinate: coord)

        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(Set([a, b]).count == 1)
    }
}
