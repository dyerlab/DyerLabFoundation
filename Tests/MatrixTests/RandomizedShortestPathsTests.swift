//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RandomizedShortestPathsTests.swift
//  MatrixTests
//
//  gdistance parity cases come from Fixtures/generate_rsp_fixtures.R. The θ
//  limits are checked against quantities computed here independently: the
//  reference walk's expected cost by a dense solve, and least cost by Dijkstra.
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import Matrix

// MARK: - Fixtures

private struct RSPFixtureFile: Decodable {
    let cases: [RSPFixture]
}

private struct RSPFixture: Decodable {
    struct Extent: Decodable { let west, east, south, north: Double }
    struct Site: Decodable { let longitude, latitude: Double }
    struct Distances: Decodable { let total, net: [[Double]]; let free: [[Double?]] }
    struct ThetaCase: Decodable { let theta: Double; let conductance, areaCorrected: Distances }

    let id: String
    let crs: String
    let rows: Int
    let cols: Int
    let extent: Extent
    let directions: Int
    let values: [Double?]
    let sites: [Site]
    let steps: [[Double]]
    let leastCost: [[Double]]
    let thetas: [ThetaCase]

    func raster() throws -> Raster {
        let extent = try #require(RasterExtent(west: extent.west, east: extent.east, south: extent.south,
                                               north: extent.north))
        let crs = try #require(CoordinateReferenceSystem(definition: crs))
        return try #require(Raster(name: id, rows: rows, cols: cols, extent: extent, crs: crs,
                                   values: values.map { $0.map(Float.init) ?? .nan }))
    }

    func graph(_ walk: CellGraph.ReferenceWalk = .conductance) throws -> CellGraph {
        try #require(CellGraph(resistance: try raster(), neighbours: directions == 8 ? .eight : .four,
                               referenceWalk: walk))
    }

    func siteNodes(on graph: CellGraph) throws -> [Int] {
        try sites.map { try #require(graph.node(longitude: $0.longitude, latitude: $0.latitude)) }
    }
}

private func loadRSPFixtures() throws -> [String: RSPFixture] {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("Fixtures/rsp_fixtures.json")
    let file = try JSONDecoder().decode(RSPFixtureFile.self, from: Data(contentsOf: url))
    return Dictionary(uniqueKeysWithValues: file.cases.map { ($0.id, $0) })
}

private let fixtureIDs = ["utm_queen", "utm_rook", "lonlat_30n", "lonlat_60n"]

/// The largest relative difference between two matrices, treating entries both zero as equal.
private func worstRelativeDifference(_ a: [[Double]], _ b: [[Double?]]) -> Double {
    var worst = 0.0
    for (rowA, rowB) in zip(a, b) {
        for (x, y) in zip(rowA, rowB) {
            guard let y else { continue }
            worst = max(worst, abs(x - y) / max(abs(y), 1e-12))
        }
    }
    return worst
}

/// A landscape of uniform resistance with a few bumps, for the limit tests.
private func testSurface(rows: Int = 6, cols: Int = 7, missingColumn: Int? = nil) throws -> Raster {
    var values: [Float] = []
    for row in 0 ..< rows {
        for col in 0 ..< cols {
            values.append(col == missingColumn ? .nan : 1 + Float((row * 7 + col * 3) % 5))
        }
    }
    let extent = try #require(RasterExtent(west: 500_000, east: 500_000 + Double(cols) * 50,
                                           south: 3_300_000, north: 3_300_000 + Double(rows) * 50))
    let crs = try #require(CoordinateReferenceSystem(epsg: 32612))
    return try #require(Raster(name: "test", rows: rows, cols: cols, extent: extent, crs: crs, values: values))
}

/// The reference walk's expected cost of reaching `target` from every node, by a dense solve of
/// (I − P_t) h = (P ∘ C) 1, with the target's row of P zeroed.
private func randomWalkCosts(_ graph: CellGraph, target: Int) -> [Double] {
    let n = graph.nodeCount
    var a = [[Double]](repeating: [Double](repeating: 0, count: n + 1), count: n)
    for k in 0 ..< n {
        a[k][k] = 1
        guard k != target else { continue }
        let steps = graph.steps(from: k)
        let total = steps.reduce(0) { $0 + graph.walkWeights[$1] }
        for step in steps {
            let p = graph.walkWeights[step] / total
            a[k][Int(graph.targets[step])] -= p
            a[k][n] += p * graph.costs[step]
        }
    }
    // Gaussian elimination with partial pivoting.
    for column in 0 ..< n {
        let pivot = (column ..< n).max { abs(a[$0][column]) < abs(a[$1][column]) }!
        a.swapAt(column, pivot)
        for row in 0 ..< n where row != column && a[row][column] != 0 {
            let factor = a[row][column] / a[column][column]
            for k in column ... n { a[row][k] -= factor * a[column][k] }
        }
    }
    return (0 ..< n).map { a[$0][n] / a[$0][$0] }
}

// MARK: - Tests

struct RandomizedShortestPathsTests {

    // MARK: gdistance parity

    @Test(arguments: fixtureIDs)
    func stepCostsMatchGdistance(_ id: String) throws {
        let fixture = try #require(try loadRSPFixtures()[id])
        let graph = try fixture.graph()
        #expect(graph.stepCount == fixture.steps.count)
        var worst = 0.0
        for step in fixture.steps {
            let cost = try #require(graph.stepCost(from: Int(step[0]), to: Int(step[1])))
            worst = max(worst, abs(cost - step[2]) / step[2])
        }
        // Vincenty against GeographicLib: well under a millimetre per kilometre.
        #expect(worst < 1e-9, "worst relative step-cost difference \(worst)")
    }

    @Test(arguments: fixtureIDs)
    func leastCostMatchesCostDistance(_ id: String) throws {
        let fixture = try #require(try loadRSPFixtures()[id])
        let graph = try fixture.graph()
        let sites = try fixture.siteNodes(on: graph)
        let distances = try #require(graph.leastCostDistances(from: sites, to: sites))
        #expect(worstRelativeDifference(distances, fixture.leastCost) < 1e-10)
    }

    @Test(arguments: fixtureIDs)
    func matchesRSPDistance(_ id: String) throws {
        let fixture = try #require(try loadRSPFixtures()[id])
        for walk in [CellGraph.ReferenceWalk.conductance, .areaCorrected] {
            let graph = try fixture.graph(walk)
            let sites = try fixture.siteNodes(on: graph)
            for thetaCase in fixture.thetas {
                let expected = walk == .conductance ? thetaCase.conductance : thetaCase.areaCorrected
                let rsp = try #require(RandomizedShortestPaths(graph: graph, theta: thetaCase.theta))
                let label = "\(id) \(walk) θ = \(thetaCase.theta)"
                let total = try #require(rsp.distances(from: sites, to: sites, measure: .expectedCost))
                let net = try #require(rsp.distances(from: sites, to: sites, measure: .netExpectedCost))
                #expect(worstRelativeDifference(total, expected.total) < 1e-8, "\(label) total")
                #expect(worstRelativeDifference(net, expected.net) < 1e-8, "\(label) net")
                if thetaCase.theta > 0 {
                    let free = try #require(rsp.distances(from: sites, to: sites, measure: .freeEnergy))
                    #expect(worstRelativeDifference(free, expected.free) < 1e-8, "\(label) free energy")
                } else {
                    #expect(rsp.distances(from: sites, to: sites, measure: .freeEnergy) == nil)
                }
            }
        }
    }

    // MARK: θ limits

    @Test func smallThetaReachesTheRandomWalksCost() throws {
        let graph = try #require(CellGraph(resistance: try testSurface()))
        let sites = [0, 9, 23, graph.nodeCount - 1]
        let walk = sites.map { randomWalkCosts(graph, target: $0) }
        let exact = try #require(RandomizedShortestPaths(graph: graph, theta: 0))
        // The gap from the limit is about θ × the spread of the walk's cost, which is ~1e5 here, so θ must be
        // far below 1e-5 / 1e5 for a 1e-5 agreement.
        let tiny = try #require(RandomizedShortestPaths(graph: graph, theta: 1e-11))
        let atZero = try #require(exact.distances(from: sites, to: sites, measure: .expectedCost))
        let free = try #require(tiny.distances(from: sites, to: sites, measure: .freeEnergy))
        let total = try #require(tiny.distances(from: sites, to: sites, measure: .expectedCost))
        for (i, origin) in sites.enumerated() {
            for (j, _) in sites.enumerated() where i != j {
                let reference = walk[j][origin]
                #expect(abs(atZero[i][j] - reference) / reference < 1e-10)
                #expect(abs(total[i][j] - reference) / reference < 1e-5)
                #expect(abs(free[i][j] - reference) / reference < 1e-5)
            }
        }
    }

    @Test func largeThetaReachesLeastCost() throws {
        let graph = try #require(CellGraph(resistance: try testSurface()))
        let sites = [0, 9, 23, graph.nodeCount - 1]
        let least = try #require(graph.leastCostDistances(from: sites, to: sites))
        var previous: [RandomizedShortestPaths.Measure: [[Double]]] = [:]
        for theta in [1e-4, 1e-3, 1e-2, 0.1, 0.5] {
            let rsp = try #require(RandomizedShortestPaths(graph: graph, theta: theta))
            for measure in [RandomizedShortestPaths.Measure.freeEnergy, .expectedCost, .netExpectedCost] {
                let d = try #require(rsp.distances(from: sites, to: sites, measure: measure), "θ = \(theta)")
                for i in sites.indices {
                    for j in sites.indices where i != j {
                        // No walk costs less than the cheapest path, and raising θ only brings the cost down.
                        #expect(d[i][j] >= least[i][j] * (1 - 1e-12), "\(measure) θ = \(theta)")
                        if let earlier = previous[measure] {
                            #expect(d[i][j] <= earlier[i][j] * (1 + 1e-12), "\(measure) θ = \(theta)")
                        }
                        if theta == 0.5 && measure != .freeEnergy {
                            #expect(abs(d[i][j] - least[i][j]) / least[i][j] < 1e-3, "\(measure)")
                        }
                    }
                }
                previous[measure] = d
            }
        }
    }

    // MARK: Behaviour

    @Test func separateRegionsAreInfinitelyFarApart() throws {
        let graph = try #require(CellGraph(resistance: try testSurface(missingColumn: 3)))
        #expect(graph.regionCount == 2)
        #expect(graph.notes.contains { $0.logType == .warning && $0.message.contains("2 separate regions") })
        let west = try #require(graph.cells.firstIndex(of: 0))
        let east = try #require(graph.cells.firstIndex(of: 6))
        let alsoWest = try #require(graph.cells.firstIndex(of: 7 * 5 + 1))
        let rsp = try #require(RandomizedShortestPaths(graph: graph, theta: 1e-3))
        let d = try #require(rsp.distances(from: [west, east, alsoWest], to: [west, east, alsoWest],
                                           measure: .netExpectedCost))
        #expect(d[0][1] == .infinity && d[1][0] == .infinity && d[1][2] == .infinity)
        #expect(d[0][2].isFinite && d[2][0].isFinite)
        #expect(d[0][0] == 0 && d[1][1] == 0)
        let least = try #require(graph.leastCostDistances(from: [west], to: [east, alsoWest]))
        #expect(least[0][0] == .infinity && least[0][1].isFinite)
    }

    @Test func underflowIsReportedRatherThanReturnedAsInfinity() throws {
        let graph = try #require(CellGraph(resistance: try testSurface()))
        let rsp = try #require(RandomizedShortestPaths(graph: graph, theta: 50))
        #expect(rsp.distances(from: [0], to: [graph.nodeCount - 1], measure: .freeEnergy) == nil)
    }

    @Test func rejectsUnusableInput() throws {
        let surface = try testSurface()
        let negative = try #require(Raster(name: "bad", rows: surface.rows, cols: surface.cols, extent: surface.extent,
                                           crs: surface.crs, values: surface.values.enumerated().map {
                                               $0.offset == 4 ? -1 : $0.element }))
        #expect(CellGraph(resistance: negative) == nil)
        let graph = try #require(CellGraph(resistance: surface))
        #expect(RandomizedShortestPaths(graph: graph, theta: -1) == nil)
        #expect(RandomizedShortestPaths(graph: graph, theta: .infinity) == nil)
        let rsp = try #require(RandomizedShortestPaths(graph: graph, theta: 1e-3))
        #expect(rsp.distances(from: [graph.nodeCount], to: [0], measure: .expectedCost) == nil)
        #expect(graph.leastCostDistances(from: [-1], to: [0]) == nil)
    }

    // MARK: Notes

    @Test func warnsAboutHighLatitudesAndCellCounting() throws {
        let fixture = try #require(try loadRSPFixtures()["lonlat_60n"])
        let raster = try fixture.raster()
        let ground = try #require(CellGraph(resistance: raster))
        #expect(ground.notes.contains { $0.logType == .warning && $0.message.contains("60") })
        #expect(ground.notes.contains { $0.message.contains("cosine of their latitude") })
        #expect(!ground.notes.contains { $0.message.contains("counted in cells") })
        let counted = try #require(CellGraph(resistance: raster, stepLength: .cellSteps))
        let warning = try #require(counted.notes.first { $0.message.contains("counted in cells") })
        // At 60° N an east–west 0.01° step is about half a north–south one.
        #expect(warning.message.contains("49") || warning.message.contains("50"))
        #expect(ground.notes.contains { $0.message.contains("cells without a value were impassable") })
    }

    @Test func warnsAboutCoarseCells() throws {
        let bounds = try #require(GeographicBounds(west: -120, east: -110, south: 30, north: 40))
        let raster = try #require(Raster(name: "coarse", rows: 10, cols: 10, bounds: bounds,
                                         values: [Float](repeating: 1, count: 100)))
        let graph = try #require(CellGraph(resistance: raster))
        #expect(graph.notes.contains { $0.logType == .warning && $0.message.contains("° tall") })
        let fine = try testSurface()
        #expect(try #require(CellGraph(resistance: fine)).notes.allSatisfy { $0.logType == .assumption })
    }

    // MARK: Geodesic

    @Test func geodesicMatchesVincentysTestLine() throws {
        // Flinders Peak to Buninyong on GRS 80 (Geoscience Australia's worked example): 54,972.271 m.
        let flinders = (longitude: 144 + 25 / 60.0 + 29.52440 / 3600, latitude: -(37 + 57 / 60.0 + 3.72030 / 3600))
        let buninyong = (longitude: 143 + 55 / 60.0 + 35.38390 / 3600, latitude: -(37 + 39 / 60.0 + 10.15610 / 3600))
        let distance = try #require(Ellipsoid.grs80.distance(fromLongitude: flinders.longitude,
                                                             latitude: flinders.latitude,
                                                             toLongitude: buninyong.longitude,
                                                             latitude: buninyong.latitude))
        #expect(abs(distance - 54_972.271) < 1e-3)
        #expect(Ellipsoid.wgs84.distance(fromLongitude: 10, latitude: 20, toLongitude: 10, latitude: 20) == 0)
    }
}
