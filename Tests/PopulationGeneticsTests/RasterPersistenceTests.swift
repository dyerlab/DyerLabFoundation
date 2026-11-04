//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RasterPersistenceTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix
import Testing
@testable import PopulationGenetics

struct RasterPersistenceTests {

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".db")
    }

    private func makeRaster(name: String, offset: Float = 0, epsg: Int = 4326) throws -> Raster {
        let bounds = try #require(GeographicBounds(west: -77.6, east: -77.2, south: 37.4, north: 37.65))
        var values = (0 ..< 12).map { Float($0) * 1.5 + offset }
        values[5] = .nan
        return try #require(Raster(name: name, rows: 3, cols: 4, bounds: bounds, epsg: epsg, values: values))
    }

    @Test func rasterRoundTripsWithMissingCells() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ProjectStore()
        try await store.create(at: url, components: .rasters, projectName: "Rasters")
        let elevation = try makeRaster(name: "elevation", epsg: 4269)
        try await store.writeRaster(elevation, description: "SRTM 1 arc-second")
        await store.close()

        try await store.open(at: url, mode: .readOnly)
        #expect(await store.presentComponents == .rasters)
        let info = try #require(try await store.rasters().first)
        #expect(info.name == "elevation")
        #expect(info.description == "SRTM 1 arc-second")
        #expect(info.rows == 3 && info.cols == 4 && info.crs == .geographic(epsg: 4269))
        #expect(info.extent == elevation.extent)
        #expect(try await store.raster(named: "elevation") == elevation)
        #expect(try await store.raster(named: "absent") == nil)
        #expect(try await store.readSummary().hasRasters == true)
        await store.close()
    }

    @Test func writingTheSameNameReplacesTheLayerInPlace() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ProjectStore()
        try await store.create(at: url, components: .rasters, projectName: "Rasters")
        try await store.writeRaster(makeRaster(name: "elevation"))
        try await store.writeRaster(makeRaster(name: "nlcd_forest"))
        let firstID = try #require(try await store.rasters().first?.id)
        let replacement = try makeRaster(name: "elevation", offset: 100)
        try await store.writeRaster(replacement, description: "re-imported")

        let infos = try await store.rasters()
        #expect(infos.map(\.name) == ["elevation", "nlcd_forest"])
        #expect(infos.first?.id == firstID)
        #expect(infos.first?.description == "re-imported")
        #expect(try await store.raster(named: "elevation") == replacement)
        await store.close()
    }

    @Test func removingTheLastLayerClearsTheFlag() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ProjectStore()
        try await store.create(at: url, components: .rasters, projectName: "Rasters")
        try await store.writeRaster(makeRaster(name: "elevation"))
        #expect(try await store.removeRaster(named: "elevation"))
        #expect(try await store.removeRaster(named: "elevation") == false)
        #expect(try await store.rasters().isEmpty)
        #expect(try await store.readSummary().hasRasters == false)
        await store.close()
    }

    @Test func fileWithoutRastersReportsTheComponentMissing() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ProjectStore()
        try await store.create(at: url, components: .log, projectName: "No rasters")
        await #expect(throws: PersistenceError.componentNotPresent("rasters")) {
            try await store.writeRaster(try makeRaster(name: "elevation"))
        }
        #expect(try await store.readSummary().hasRasters == nil)
        await store.close()
    }

    @Test func snapshotCarriesRasters() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let layers = [RasterAttachment(raster: try makeRaster(name: "elevation"), description: "DEM"),
                      RasterAttachment(raster: try makeRaster(name: "nlcd_forest", offset: 3))]
        try await ProjectStore.saveSnapshot(rasters: layers, projectName: "Snapshot", to: url)
        let snapshot = try await ProjectStore.loadSnapshot(from: url)
        #expect(snapshot.rasters == layers)
        #expect(snapshot.matrices.isEmpty)
    }

    @Test func projectedRastersKeepTheirCoordinateSystem() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let extent = try #require(RasterExtent(west: 300_000, east: 304_000, south: 4_150_000, north: 4_153_000))
        let albers = try #require(CoordinateReferenceSystem(epsg: 5070))
        let nlcd = try #require(Raster(name: "nlcd_forest", rows: 3, cols: 4, extent: extent, crs: albers,
                                       values: [0, 1, 1, 0, 1, 1, .nan, 0, 0, 0, 1, 1]))
        let custom = try #require(MapProjection(transverseMercatorOn: .wgs84, latitudeOfOrigin: 37,
                                                centralMeridian: -77.5, scaleFactor: 0.9999,
                                                falseEasting: 300_000, falseNorthing: 50_000))
        let local = try #require(Raster(name: "local_dem", rows: 3, cols: 4, extent: extent,
                                        crs: .projected(custom, epsg: nil), values: (0 ..< 12).map(Float.init)))
        let store = ProjectStore()
        try await store.create(at: url, components: .rasters, projectName: "Projected")
        try await store.writeRaster(nlcd)
        try await store.writeRaster(local)
        #expect(try await store.raster(named: "nlcd_forest") == nlcd)
        #expect(try await store.raster(named: "local_dem") == local)
        let infos = try await store.rasters()
        #expect(infos.map(\.crs.definition) == ["EPSG:5070", custom.projDefinition])
        await store.close()
    }

    @Test func cellsAreStoredAsLittleEndianFloat32() {
        let bytes = RastersSchemaComponent.encode([1, .nan, -2.5])
        #expect(bytes.count == 12)
        #expect(Array(bytes[0 ..< 4]) == [0x00, 0x00, 0x80, 0x3F])
        let decoded = RastersSchemaComponent.decode(bytes, count: 3)
        #expect(decoded?[0] == 1)
        #expect(decoded?[1].isNaN == true)
        #expect(decoded?[2] == -2.5)
        #expect(RastersSchemaComponent.decode(bytes, count: 4) == nil)
    }
}
