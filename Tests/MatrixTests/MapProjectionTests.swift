//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MapProjectionTests.swift
//  MatrixTests
//
//  PROJ parity cases come from Fixtures/generate_projection_fixtures.R.
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import Matrix

private struct ProjectionFixtureFile: Decodable {
    let cases: [ProjectionFixture]
}

private struct ProjectionFixture: Decodable {
    let id: String
    let crs: String
    let points: [ProjectedPoint]
}

private struct ProjectedPoint: Decodable {
    let longitude: Double
    let latitude: Double
    let x: Double
    let y: Double
}

private func loadProjectionFixtures() throws -> [String: ProjectionFixture] {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("Fixtures/projection_fixtures.json")
    let file = try JSONDecoder().decode(ProjectionFixtureFile.self, from: Data(contentsOf: url))
    return Dictionary(uniqueKeysWithValues: file.cases.map { ($0.id, $0) })
}

struct MapProjectionTests {

    // MARK: - PROJ parity

    @Test(arguments: ["wgs84_utm12n", "wgs84_utm12s", "nad83_utm12n", "nad83_2011_utm12n", "etrs89_utm32n",
                      "conus_albers", "alaska_albers", "california_albers", "bc_albers", "custom_tmerc",
                      "custom_southern_albers", "custom_one_parallel_albers"])
    func matchesPROJ(_ id: String) throws {
        let fixture = try #require(try loadProjectionFixtures()[id])
        let crs = try #require(CoordinateReferenceSystem(definition: fixture.crs))
        let projection = try #require(crs.projection)
        var worstMetres = 0.0
        var worstDegrees = 0.0
        for point in fixture.points {
            let projected = try #require(projection.project(longitude: point.longitude, latitude: point.latitude))
            worstMetres = max(worstMetres, abs(projected.x - point.x), abs(projected.y - point.y))
            let back = try #require(projection.unproject(x: point.x, y: point.y))
            worstDegrees = max(worstDegrees, abs(back.longitude - point.longitude), abs(back.latitude - point.latitude))
        }
        // A millimetre on the ground, and about 0.1 mm going back.
        #expect(worstMetres < 1e-3, "worst projected error \(worstMetres) m")
        #expect(worstDegrees < 1e-9, "worst inverse error \(worstDegrees)°")
    }

    // MARK: - Definitions

    @Test func epsgCodesMatchPROJsDefinitions() throws {
        // PROJ strings as terra::crs("EPSG:n", proj = TRUE) prints them (PROJ 9.5).
        let proj: [Int: String] = [
            32612: "+proj=utm +zone=12 +datum=WGS84 +units=m +no_defs",
            32712: "+proj=utm +zone=12 +south +datum=WGS84 +units=m +no_defs",
            26912: "+proj=utm +zone=12 +datum=NAD83 +units=m +no_defs",
            25832: "+proj=utm +zone=32 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs",
            6330: "+proj=utm +zone=1 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs",
            6341: "+proj=utm +zone=12 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs",
            5070: "+proj=aea +lat_0=23 +lon_0=-96 +lat_1=29.5 +lat_2=45.5 +x_0=0 +y_0=0 +datum=NAD83 +units=m +no_defs",
            6350: "+proj=aea +lat_0=23 +lon_0=-96 +lat_1=29.5 +lat_2=45.5 +x_0=0 +y_0=0 +ellps=GRS80 +units=m",
            3338: "+proj=aea +lat_0=50 +lon_0=-154 +lat_1=55 +lat_2=65 +x_0=0 +y_0=0 +datum=NAD83 +units=m +no_defs",
            3310: "+proj=aea +lat_0=0 +lon_0=-120 +lat_1=34 +lat_2=40.5 +x_0=0 +y_0=-4000000 +datum=NAD83 +units=m",
            3005: "+proj=aea +lat_0=45 +lon_0=-126 +lat_1=50 +lat_2=58.5 +x_0=1000000 +y_0=0 +datum=NAD83 +units=m",
        ]
        for (code, definition) in proj {
            let registered = try #require(CoordinateReferenceSystem(epsg: code), "EPSG:\(code)")
            let parsed = try #require(CoordinateReferenceSystem(definition: definition), "EPSG:\(code)")
            #expect(registered.projection == parsed.projection, "EPSG:\(code)")
            #expect(registered.definition == "EPSG:\(code)")
        }
    }

    @Test func customDefinitionsRoundTrip() throws {
        let albers = try #require(MapProjection(albersEqualAreaOn: .grs80, latitudeOfOrigin: 20, centralMeridian: -110,
                                                standardParallel1: 24, standardParallel2: 31.25,
                                                falseEasting: 100_000, falseNorthing: -50_000))
        let custom = CoordinateReferenceSystem.projected(albers, epsg: nil)
        #expect(custom.definition.hasPrefix("+proj=aea +lat_0=20 +lon_0=-110 +lat_1=24 +lat_2=31.25"))
        #expect(CoordinateReferenceSystem(definition: custom.definition) == custom)
        let odd = try #require(Ellipsoid(semiMajorAxis: 6_378_206.4, inverseFlattening: 294.9786982))
        let clarke = CoordinateReferenceSystem.projected(MapProjection.utm(zone: 14, ellipsoid: odd)!, epsg: nil)
        #expect(CoordinateReferenceSystem(definition: clarke.definition) == clarke)
        #expect(CoordinateReferenceSystem(definition: "EPSG:4269") == .geographic(epsg: 4269))
        #expect(CoordinateReferenceSystem(definition: "+proj=longlat +datum=WGS84 +no_defs") == .wgs84)
    }

    @Test func rejectsUnsupportedSystems() {
        #expect(CoordinateReferenceSystem(epsg: 6372) == nil)       // Mexico LCC
        #expect(CoordinateReferenceSystem(epsg: 3857) == nil)       // Web Mercator
        #expect(CoordinateReferenceSystem(definition: "+proj=lcc +lat_1=17.5 +lat_2=29.5 +ellps=GRS80") == nil)
        #expect(CoordinateReferenceSystem(definition: "+proj=utm +zone=12 +datum=WGS84 +units=us-ft") == nil)
        #expect(CoordinateReferenceSystem(definition: "+proj=utm +zone=12") == nil)   // no ellipsoid
        #expect(MapProjection.utm(zone: 0) == nil)
        #expect(MapProjection.utm(zone: 61) == nil)
    }

    // MARK: - Behaviour

    @Test func transverseMercatorRejectsTheFarSideOfTheEarth() throws {
        let utm = try #require(MapProjection.utm(zone: 12))
        #expect(utm.project(longitude: 80, latitude: 10) == nil)
        let pole = try #require(utm.project(longitude: -111, latitude: 90))
        #expect(abs(pole.x - 500_000) < 1e-6)
    }

    @Test func extentEnclosesAProjectedArea() throws {
        let crs = try #require(CoordinateReferenceSystem(epsg: 5070))
        let area = try #require(GeographicBounds(west: -100, east: -90, south: 35, north: 45))
        let extent = try #require(crs.extent(enclosing: area))
        // Every corner and edge midpoint of the area projects inside the extent.
        for (longitude, latitude) in [(-100.0, 35.0), (-90, 45), (-95, 45), (-95, 35), (-100, 45)] {
            let point = try #require(crs.coordinates(longitude: longitude, latitude: latitude))
            #expect(extent.contains(x: point.x, y: point.y))
        }
        // Albers parallels are arcs around the cone's apex, lowest at the central meridian (−96°). So the far
        // north corner sets the top, and the south edge dips below both its corners.
        let northEast = try #require(crs.coordinates(longitude: -90, latitude: 45))
        let southWest = try #require(crs.coordinates(longitude: -100, latitude: 35))
        #expect(abs(extent.north - northEast.y) < 1e-6)
        #expect(extent.south < southWest.y)
        let back = try #require(crs.geographicBounds(enclosing: extent))
        #expect(back.west <= area.west && back.east >= area.east && back.south <= area.south && back.north >= area.north)
    }
}
