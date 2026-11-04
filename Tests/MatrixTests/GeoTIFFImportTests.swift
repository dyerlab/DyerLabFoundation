//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GeoTIFFImportTests.swift
//  MatrixTests
//
//  terra/GDAL parity cases come from Fixtures/generate_geotiff_fixtures.R.
//  alt_baja.tif is a real WorldClim 30-arc-second DEM of Baja California,
//  checked against terra at the arapat sampling sites.
//  Values are compared at Float precision, since that's what Raster holds.
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import Matrix

private struct GeoTIFFFixtureFile: Decodable {
    let cases: [GeoTIFFFixture]
}

private struct GeoTIFFFixture: Decodable {
    let id: String
    let file: String
    let expected: ExpectedRaster
    let crop: CropBox?
    let cropped: ExpectedRaster?
    let points: [SampledPoint]?
}

private struct CellCenter: Decodable {
    let row: Int
    let col: Int
    let longitude: Double
    let latitude: Double
}

private struct SampledPoint: Decodable {
    let population: String
    let longitude: Double
    let latitude: Double
    let value: Double?
}

private struct CropBox: Decodable {
    let west: Double
    let east: Double
    let south: Double
    let north: Double
}

private struct ExpectedRaster: Decodable {
    let rows: Int
    let cols: Int
    let west: Double
    let east: Double
    let south: Double
    let north: Double
    let epsg: Int?
    let proj: String?
    let centers: [CellCenter]?
    let missing: Int
    let sum: Double
    let sumOfSquares: Double
    let values: [Double?]?
}

private let fixtureDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Fixtures")

private func loadFixtures() throws -> [String: GeoTIFFFixture] {
    let url = fixtureDirectory.appendingPathComponent("geotiff_fixtures.json")
    let file = try JSONDecoder().decode(GeoTIFFFixtureFile.self, from: Data(contentsOf: url))
    return Dictionary(uniqueKeysWithValues: file.cases.map { ($0.id, $0) })
}

private func expectMatches(_ raster: Raster, _ expected: ExpectedRaster) {
    #expect(raster.rows == expected.rows)
    #expect(raster.cols == expected.cols)
    #expect(abs(raster.extent.west - expected.west) < 1e-9 * max(abs(expected.west), 1))
    #expect(abs(raster.extent.east - expected.east) < 1e-9 * max(abs(expected.east), 1))
    #expect(abs(raster.extent.south - expected.south) < 1e-9 * max(abs(expected.south), 1))
    #expect(abs(raster.extent.north - expected.north) < 1e-9 * max(abs(expected.north), 1))
    #expect(raster.epsg == expected.epsg)
    if let proj = expected.proj {
        // PROJ's own definition of the file's system, read by our parser, is the projection we imported.
        #expect(CoordinateReferenceSystem(definition: proj)?.projection == raster.crs.projection)
    }
    for center in expected.centers ?? [] {
        let actual = raster.cellCenter(row: center.row, col: center.col)
        #expect(abs(actual.longitude - center.longitude) < 1e-9)
        #expect(abs(actual.latitude - center.latitude) < 1e-9)
    }
    #expect(raster.missingCount == expected.missing)
    let present = raster.values.filter { !$0.isNaN }.map(Double.init)
    let sum = present.reduce(0, +)
    let sumOfSquares = present.reduce(0) { $0 + $1 * $1 }
    #expect(abs(sum - expected.sum) <= 1e-6 * max(abs(expected.sum), 1))
    #expect(abs(sumOfSquares - expected.sumOfSquares) <= 1e-6 * max(abs(expected.sumOfSquares), 1))
    guard let values = expected.values else { return }
    #expect(values.count == raster.values.count)
    var mismatches = 0
    for (actual, wanted) in zip(raster.values, values) {
        if let wanted {
            if Float(wanted) != actual { mismatches += 1 }
        } else if !actual.isNaN {
            mismatches += 1
        }
    }
    #expect(mismatches == 0)
}

struct GeoTIFFImportTests {

    // MARK: - terra parity

    @Test(arguments: ["float32_lzw_fp_predictor_tiled", "int16_deflate_predictor_strips", "uint8_packbits_strips",
                      "float64_uncompressed_bigendian_tiled", "int32_lzw_bigtiff", "uint16_lzw_predictor_bigendian",
                      "float32_nad83_deflate", "float32_lzw_large", "int16_lzw_large_tiled",
                      "float32_wgs84_utm18n_lzw", "int16_nad83_utm18n_deflate", "float32_conus_albers_tiled",
                      "float32_custom_albers", "float32_custom_tmerc"])
    func readsWhatTerraWrote(_ id: String) throws {
        let fixture = try #require(try loadFixtures()[id])
        let raster = try importGeoTIFF(contentsOf: fixtureDirectory.appendingPathComponent(fixture.file))
        #expect(raster.name == id)
        expectMatches(raster, fixture.expected)
    }

    @Test(arguments: ["float32_lzw_fp_predictor_tiled", "int16_deflate_predictor_strips",
                      "float64_uncompressed_bigendian_tiled"])
    func cropsLikeTerraWithSnapOut(_ id: String) throws {
        let fixture = try #require(try loadFixtures()[id])
        let box = try #require(fixture.crop)
        let expected = try #require(fixture.cropped)
        let area = try #require(GeographicBounds(west: box.west, east: box.east, south: box.south, north: box.north))
        let url = fixtureDirectory.appendingPathComponent(fixture.file)
        let raster = try importGeoTIFF(contentsOf: url, name: "cropped", cropTo: area)
        expectMatches(raster, expected)
        // Cropping on import and cropping afterwards give the same layer.
        let whole = try importGeoTIFF(contentsOf: url, name: "cropped")
        #expect(whole.cropped(to: area) == raster)
    }

    // MARK: - Projected rasters

    @Test(arguments: ["float32_wgs84_utm18n_lzw", "int16_nad83_utm18n_deflate", "float32_conus_albers_tiled",
                      "float32_custom_albers", "float32_custom_tmerc"])
    func cropsProjectedRasterLikeTerra(_ id: String) throws {
        let fixture = try #require(try loadFixtures()[id])
        let box = try #require(fixture.crop)
        let target = try #require(RasterExtent(west: box.west, east: box.east, south: box.south, north: box.north))
        let whole = try importGeoTIFF(contentsOf: fixtureDirectory.appendingPathComponent(fixture.file), name: "cropped")
        let cropped = try #require(whole.cropped(to: target))
        expectMatches(cropped, try #require(fixture.cropped))
    }

    @Test func cropsProjectedRasterToAStudyAreaOnImport() throws {
        let url = fixtureDirectory.appendingPathComponent("geotiff/float32_conus_albers_tiled.tif")
        let area = try #require(GeographicBounds(west: -77.45, east: -77.35, south: 37.48, north: 37.56))
        let raster = try importGeoTIFF(contentsOf: url, cropTo: area)
        #expect(raster.crs == CoordinateReferenceSystem(epsg: 5070))
        #expect(try importGeoTIFF(contentsOf: url).cropped(to: area) == raster)
        // Every corner of the study area falls inside the cropped grid.
        for (longitude, latitude) in [(area.west, area.south), (area.west, area.north),
                                      (area.east, area.south), (area.east, area.north)] {
            #expect(raster.cell(longitude: longitude, latitude: latitude) != nil)
        }
        #expect(raster.rows < 33 && raster.cols < 39)
    }

    @Test func projectedCellsAreSizedInMetres() throws {
        let url = fixtureDirectory.appendingPathComponent("geotiff/float32_wgs84_utm18n_lzw.tif")
        let raster = try importGeoTIFF(contentsOf: url)
        let size = raster.cellSize(atRow: 0)
        #expect(size.width == raster.cellWidth && size.height == raster.cellHeight)
        #expect(raster.geographicBounds.contains(longitude: -77.4, latitude: 37.5))
    }

    // MARK: - A real DEM

    @Test func readsWorldClimElevationOverBaja() throws {
        let fixture = try #require(try loadFixtures()["alt_baja"])
        let raster = try importGeoTIFF(contentsOf: fixtureDirectory.appendingPathComponent(fixture.file))
        #expect(raster.name == "alt_baja")
        expectMatches(raster, fixture.expected)
    }

    @Test func cropsElevationToTheArapatStudyArea() throws {
        let fixture = try #require(try loadFixtures()["alt_baja"])
        let sites = try #require(fixture.points)
        let box = try #require(fixture.crop)
        // The study area the R script computed is the sites' bounds buffered by 10%, as buffered() does.
        let area = try #require(GeographicBounds(longitudes: sites.map(\.longitude),
                                                 latitudes: sites.map(\.latitude))?.buffered())
        #expect(abs(area.west - box.west) < 1e-9 && abs(area.east - box.east) < 1e-9)
        #expect(abs(area.south - box.south) < 1e-9 && abs(area.north - box.north) < 1e-9)

        let url = fixtureDirectory.appendingPathComponent(fixture.file)
        let raster = try importGeoTIFF(contentsOf: url, cropTo: area)
        expectMatches(raster, try #require(fixture.cropped))
        #expect(try importGeoTIFF(contentsOf: url).cropped(to: area) == raster)
    }

    @Test func elevationAtEachArapatSiteMatchesTerra() throws {
        let fixture = try #require(try loadFixtures()["alt_baja"])
        let sites = try #require(fixture.points)
        let raster = try importGeoTIFF(contentsOf: fixtureDirectory.appendingPathComponent(fixture.file))
        for site in sites {
            let value = raster.value(longitude: site.longitude, latitude: site.latitude)
            if let expected = site.value {
                #expect(value == Float(expected), "population \(site.population)")
            } else {
                #expect(value?.isNaN ?? true, "population \(site.population)")
            }
        }
    }

    // MARK: - Rejections

    @Test func rejectsUnsupportedProjection() throws {
        let url = fixtureDirectory.appendingPathComponent("geotiff/projected_lcc.tif")
        #expect(throws: RasterImportError.unsupportedCoordinateSystem("EPSG:6372, \"Mexico ITRF2008 / LCC\"")) {
            try importGeoTIFF(contentsOf: url)
        }
    }

    @Test func rejectsMultibandRaster() throws {
        let url = fixtureDirectory.appendingPathComponent("geotiff/two_bands.tif")
        #expect(throws: RasterImportError.multipleBands(2)) {
            try importGeoTIFF(contentsOf: url)
        }
    }

    @Test func rejectsCropOutsideRaster() throws {
        let url = fixtureDirectory.appendingPathComponent("geotiff/uint8_packbits_strips.tif")
        let elsewhere = try #require(GeographicBounds(west: 10, east: 11, south: 10, north: 11))
        #expect(throws: RasterImportError.cropOutsideRaster) {
            try importGeoTIFF(contentsOf: url, cropTo: elsewhere)
        }
    }

    @Test func rejectsNonTIFFData() {
        #expect(throws: RasterImportError.malformedTIFF("missing byte-order mark")) {
            try importGeoTIFF(data: Data("not a tiff at all".utf8), name: "x")
        }
    }

    @Test func reportsMissingFile() {
        let url = fixtureDirectory.appendingPathComponent("geotiff/does_not_exist.tif")
        #expect(throws: RasterImportError.self) {
            try importGeoTIFF(contentsOf: url)
        }
    }

    // MARK: - Decompression

    @Test func packBitsDecodesLiteralAndRepeatRuns() {
        // From the TIFF 6.0 specification's PackBits example.
        let packed: [UInt8] = [0xFE, 0xAA, 0x02, 0x80, 0x00, 0x2A, 0xFD, 0xAA, 0x03, 0x80, 0x00, 0x2A, 0x22,
                               0xF7, 0xAA]
        let expected: [UInt8] = [0xAA, 0xAA, 0xAA, 0x80, 0x00, 0x2A, 0xAA, 0xAA, 0xAA, 0xAA, 0x80, 0x00, 0x2A,
                                 0x22, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA]
        #expect(TIFFDecompression.packBits(Data(packed), expectedCount: expected.count) == expected)
    }
}
