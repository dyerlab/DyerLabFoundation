//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RasterTests.swift
//  MatrixTests
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import Matrix

struct RasterTests {

    /// A 4 × 5 grid of 0.1° cells over 0…0.5°E, 0…0.4°N, valued `row * 10 + col`, with cell (1, 2) missing.
    private func sample() throws -> Raster {
        let bounds = try #require(GeographicBounds(west: 0, east: 0.5, south: 0, north: 0.4))
        var values = (0 ..< 20).map { Float(($0 / 5) * 10 + $0 % 5) }
        values[7] = .nan
        return try #require(Raster(name: "sample", rows: 4, cols: 5, bounds: bounds, values: values))
    }

    // MARK: - GeographicBounds

    @Test func boundsRejectInvertedOrOutOfRangeEdges() {
        #expect(GeographicBounds(west: 1, east: 0, south: 0, north: 1) == nil)
        #expect(GeographicBounds(west: 0, east: 1, south: 0, north: 91) == nil)
        #expect(GeographicBounds(west: .nan, east: 1, south: 0, north: 1) == nil)
    }

    @Test func boundsEncloseThePointsAndBufferByAFraction() throws {
        let bounds = try #require(GeographicBounds(longitudes: [-77.5, -77.3, -77.4], latitudes: [37.5, 37.6, 37.55]))
        #expect(abs(bounds.width - 0.2) < 1e-12)
        let buffered = bounds.buffered(by: 0.1, minimum: 0)
        #expect(abs(buffered.west - -77.52) < 1e-12)
        #expect(abs(buffered.east - -77.28) < 1e-12)
        #expect(abs(buffered.south - 37.49) < 1e-12)
        #expect(abs(buffered.north - 37.61) < 1e-12)
    }

    @Test func bufferingASinglePointUsesTheMinimumAndClampsToThePole() throws {
        let point = try #require(GeographicBounds(longitudes: [10], latitudes: [89.995]))
        let buffered = point.buffered(by: 0.1, minimum: 0.01)
        #expect(abs(buffered.width - 0.02) < 1e-12)
        #expect(buffered.north == 90)
    }

    @Test func intersectionIsNilWithoutOverlap() throws {
        let a = try #require(GeographicBounds(west: 0, east: 1, south: 0, north: 1))
        let b = try #require(GeographicBounds(west: 1, east: 2, south: 0, north: 1))
        #expect(a.intersection(b) == nil)
    }

    // MARK: - Raster

    @Test func rasterRejectsWrongValueCountAndUnsupportedCRS() throws {
        let bounds = try #require(GeographicBounds(west: 0, east: 1, south: 0, north: 1))
        #expect(Raster(name: "x", rows: 2, cols: 2, bounds: bounds, values: [1, 2, 3]) == nil)
        #expect(Raster(name: "x", rows: 1, cols: 1, bounds: bounds, epsg: 5070, values: [1]) == nil)
        #expect(Raster(name: "x", rows: 1, cols: 1, bounds: bounds, epsg: 4269, values: [1]) != nil)
    }

    @Test func valuesAreRowMajorFromTheNorth() throws {
        let raster = try sample()
        #expect(raster[0, 0] == 0)
        #expect(raster[3, 4] == 34)
        #expect(raster.value(row: 1, col: 2) == nil)
        #expect(raster.value(row: 9, col: 0) == nil)
        #expect(raster.missingCount == 1)
        #expect(raster.valueRange == 0 ... 34)
    }

    @Test func pointLookupFindsTheContainingCell() throws {
        let raster = try sample()
        #expect(raster.value(longitude: 0.05, latitude: 0.35) == 0)
        #expect(raster.value(longitude: 0.45, latitude: 0.05) == 34)
        // The east and south edges belong to the last column and row.
        #expect(raster.value(longitude: 0.5, latitude: 0) == 34)
        #expect(raster.value(longitude: 0.6, latitude: 0.2) == nil)
        let center = raster.cellCenter(row: 1, col: 2)
        #expect(abs(center.longitude - 0.25) < 1e-12)
        #expect(abs(center.latitude - 0.25) < 1e-12)
    }

    @Test func croppingKeepsEveryOverlappingCell() throws {
        let raster = try sample()
        let area = try #require(GeographicBounds(west: 0.15, east: 0.3, south: 0.12, north: 0.28))
        let cropped = try #require(raster.cropped(to: area))
        #expect(cropped.rows == 2)
        #expect(cropped.cols == 2)
        // Cell (1, 2) is the missing one, shown here as -1.
        #expect(cropped.values.map { $0.isNaN ? -1 : $0 } == [11, -1, 21, 22])
        #expect(abs(cropped.extent.west - 0.1) < 1e-12)
        #expect(abs(cropped.extent.north - 0.3) < 1e-12)
    }

    @Test func cropEdgesOnCellEdgesDoNotPullInNeighbours() throws {
        let raster = try sample()
        let area = try #require(GeographicBounds(west: 0.1, east: 0.3, south: 0.1, north: 0.3))
        let cropped = try #require(raster.cropped(to: area))
        #expect(cropped.rows == 2)
        #expect(cropped.cols == 2)
    }

    @Test func cellWidthShrinksWithLatitude() throws {
        let bounds = try #require(GeographicBounds(west: 0, east: 1, south: 59.5, north: 60.5))
        let raster = try #require(Raster(name: "x", rows: 1, cols: 1, bounds: bounds, values: [1]))
        let size = raster.cellSize(atRow: 0)
        #expect(abs(size.height - 111_195) < 10)
        #expect(abs(size.width / size.height - 0.5) < 1e-9)
    }

    @Test func matrixHoldsTheSameCells() throws {
        let matrix = try sample().makeMatrix()
        #expect(matrix.rows == 4)
        #expect(matrix.cols == 5)
        #expect(matrix[3, 4] == 34)
        #expect(matrix[1, 2].isNaN)
    }

    @Test func missingCellsCompareEqual() throws {
        #expect(try sample() == sample())
    }

    // MARK: - Colour ramp

    @Test func rampInterpolatesBetweenStops() {
        let color = RasterColorRamp.grayscale.color(at: 0.25)
        #expect(abs(color.red - 0.25) < 1e-12)
        #expect(RasterColorRamp.grayscale.color(at: 2).red == 1)
    }

    @Test func imageHasOnePixelPerCellAndTransparentMissingCells() throws {
        let raster = try sample()
        let image = try #require(RasterColorRamp.viridis.makeImage(raster: raster))
        #expect(image.width == 5)
        #expect(image.height == 4)
        let stretched = try #require(RasterColorRamp.viridis.makeImage(raster: raster, width: 5, height: 6) { row, col in
            min(row * 4 / 6, 3) * 5 + col
        })
        #expect(stretched.height == 6)
        #expect(RasterColorRamp.viridis.makeImage(raster: raster, width: 0, height: 1) { _, _ in 0 } == nil)
    }
}
