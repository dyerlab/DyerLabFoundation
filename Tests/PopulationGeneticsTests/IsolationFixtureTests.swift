//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IsolationFixtureTests.swift
//  PopulationGeneticsTests
//
//  Isolation by graph distance and directional isolation by graph distance from
//  genotypes, against gstudio's genetic_isolation(mode = "IBGD" / "dcGD"), and
//  dcGD among strata against genetic_distance(mode = "dcGD")
//  (Fixtures/generate_isolation_fixtures.R). Mantel P matches gstudio's
//  permutations for the same seed; the directional fit has no P. Also the
//  directional spec's JSON and a saved directional analysis.
//
//  Created by Rodney Dyer on 2026.11.21.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix
import PresentationZen
import Testing
@testable import PopulationGenetics

private struct FIBGD: Decodable {
    let r: Double; let p: Double; let pairs: Int; let r2: Double; let slope: Double
}

private struct FDCGD: Decodable {
    let delta_R2: Double; let pairs: Int; let R2_cGD: Double; let adj_R2_dcGD: Double
    let forward_slope: Double; let reverse_slope: Double; let slope_ratio: Double
}

private struct FMatrix: Decodable {
    let names: [String]; let values: [Double]
}

private struct FGravity: Decodable {
    let seed: UInt64; let nperm: Int
    let axis: [String: Double]; let scrambled_axis: [String: Double]
    let ibgd: FIBGD; let dcgd: FDCGD; let scrambled_ibgd: FIBGD; let scrambled_dcgd: FDCGD
}

private struct FArapat: Decodable {
    let seed: UInt64; let nperm: Int
    let ibgd: FIBGD; let ibgd_latitude: FIBGD; let ibgd_longitude: FIBGD
    let dcgd_latitude: FDCGD; let dcgd_km: FDCGD; let dcgd_matrix: FMatrix
}

private struct FIsolation: Decodable {
    let gravity: FGravity; let arapat: FArapat
}

struct IsolationFixtureTests {

    private static let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("Fixtures")

    private func fixture() throws -> FIsolation {
        try DistanceFixtureData.decoder.decode(FIsolation.self,
                                 from: Data(contentsOf: Self.directory.appendingPathComponent("isolation_fixtures.json")))
    }

    private func gravity() throws -> ImportedDataset {
        let csv = try String(contentsOf: Self.directory.appendingPathComponent("gravity_genotypes.csv"), encoding: .utf8)
        return try importPopulationTable(csv: csv, layout: PopulationImportLayout(strataColumns: ["Population"],
                                                                                  nameColumn: "ID"))
    }

    private func run(_ spec: IBDSpec, _ dataset: ImportedDataset) throws -> IBDResult {
        try #require(try IBDAnalysis(spec: spec, dataset: dataset).run())
    }

    private func close(_ a: Double?, _ b: Double, _ tolerance: Double = 1e-9) -> Bool {
        a.map { abs($0 - b) <= tolerance * max(1, abs(b)) } ?? false
    }

    private func expectIBGD(_ result: IBDResult, _ expected: FIBGD, sourceLocation: SourceLocation = #_sourceLocation) {
        let summary = result.spec.result
        #expect(close(summary?.r, expected.r), "r", sourceLocation: sourceLocation)
        #expect(close(summary?.p, expected.p), "P \(String(describing: summary?.p))", sourceLocation: sourceLocation)
        #expect(close(summary?.r2, expected.r2), "R²", sourceLocation: sourceLocation)
        #expect(close(summary?.slope, expected.slope), "slope", sourceLocation: sourceLocation)
        #expect(summary?.pairs == expected.pairs, sourceLocation: sourceLocation)
    }

    private func expectDCGD(_ result: IBDResult, _ expected: FDCGD, sourceLocation: SourceLocation = #_sourceLocation) {
        let summary = result.spec.result
        #expect(close(summary?.deltaR2, expected.delta_R2), "ΔR²", sourceLocation: sourceLocation)
        #expect(close(summary?.r2, expected.R2_cGD), "R² cGD", sourceLocation: sourceLocation)
        #expect(close(summary?.adjustedR2, expected.adj_R2_dcGD), "adj R² dcGD", sourceLocation: sourceLocation)
        #expect(close(summary?.forwardSlope, expected.forward_slope), "forward", sourceLocation: sourceLocation)
        #expect(close(summary?.reverseSlope, expected.reverse_slope), "reverse", sourceLocation: sourceLocation)
        #expect(close(summary?.slopeRatio, expected.slope_ratio), "ratio", sourceLocation: sourceLocation)
        #expect(summary?.orderedPairs == expected.pairs, sourceLocation: sourceLocation)
    }

    private static let population = "Population"

    // MARK: - gravity, along the deme axis

    @Test func gravityIsolationByGraphDistanceMatchesR() throws {
        let f = try fixture().gravity
        let dataset = try gravity()
        for (axis, expected) in [(f.axis, f.ibgd), (f.scrambled_axis, f.scrambled_ibgd)] {
            let spec = IBDSpec(genetic: DistanceSpec(measure: .cgd, level: Self.population),
                               axis: IBDSpec.Axis(source: .positions, name: "Deme", positions: axis),
                               permutations: f.nperm, seed: f.seed)
            let result = try run(spec, dataset)
            expectIBGD(result, expected)
            #expect(result.directional == nil)
            #expect(result.report.methods.contains("Isolation by graph distance"))
        }
    }

    @Test func gravityDirectionalIsolationByGraphDistanceMatchesR() throws {
        let f = try fixture().gravity
        let dataset = try gravity()
        let cases = [(f.axis, f.ibgd, f.dcgd), (f.scrambled_axis, f.scrambled_ibgd, f.scrambled_dcgd)]
        for (axis, ibgd, dcgd) in cases {
            let spec = IBDSpec(genetic: DistanceSpec(measure: .dcgd, level: Self.population),
                               axis: IBDSpec.Axis(source: .positions, name: "Deme", positions: axis),
                               permutations: f.nperm, seed: f.seed)
            let result = try run(spec, dataset)
            // The cGD test first, as ibgd(mode = "cGD"), then the directional fit, as ibgd(mode = "dcGD").
            expectIBGD(result, ibgd)
            expectDCGD(result, dcgd)
            let directional = try #require(result.directional)
            #expect(directional.forwardPoints.count + directional.reversePoints.count == dcgd.pairs)
            #expect(result.report.methods.contains("Dyer, in review"))
            #expect(result.report.results.contains("ΔR²"))
        }
    }

    // MARK: - arapat, great-circle distance and latitude

    @Test func arapatIsolationByGraphDistanceMatchesR() throws {
        let f = try fixture().arapat
        let dataset = try DistanceFixtureData.completeArapat()
        let cgd = DistanceSpec(measure: .cgd, level: Self.population)
        expectIBGD(try run(IBDSpec(genetic: cgd, permutations: f.nperm, seed: f.seed), dataset), f.ibgd)
        expectIBGD(try run(IBDSpec(genetic: cgd, axis: IBDSpec.Axis(source: .latitude), permutations: f.nperm,
                                   seed: f.seed), dataset), f.ibgd_latitude)
        expectIBGD(try run(IBDSpec(genetic: cgd, axis: IBDSpec.Axis(source: .longitude), permutations: f.nperm,
                                   seed: f.seed), dataset), f.ibgd_longitude)
    }

    @Test func arapatDirectionalIsolationByGraphDistanceMatchesR() throws {
        let f = try fixture().arapat
        let dataset = try DistanceFixtureData.completeArapat()
        let dcgd = DistanceSpec(measure: .dcgd, level: Self.population)
        let alongLatitude = try run(IBDSpec(genetic: dcgd, axis: IBDSpec.Axis(source: .latitude)), dataset)
        expectDCGD(alongLatitude, f.dcgd_latitude)
        #expect(alongLatitude.spec.separationLabel == "Latitude difference (°)")
        #expect(alongLatitude.spec.formula == "dcGD ~ Δlat | Population")

        // Great-circle separation, with latitude only giving the direction.
        let km = try run(IBDSpec(genetic: dcgd, axis: IBDSpec.Axis(source: .latitude), alongAxis: false), dataset)
        expectDCGD(km, f.dcgd_km)
        #expect(km.spec.separationLabel == "Great-circle distance (km)")
    }

    @Test func dcgdAmongStrataMatchesR() throws {
        let expected = try fixture().arapat.dcgd_matrix
        let dataset = try DistanceFixtureData.completeArapat()
        let result = try #require(DistanceAnalysis(spec: DistanceSpec(measure: .dcgd, level: Self.population),
                                                   dataset: dataset)?.run())
        #expect(result.isDirected)
        #expect(result.matrix.groupNames == expected.names)
        let values = result.values
        let n = expected.names.count
        var asymmetric = false
        for i in 0..<n {
            for j in 0..<n {
                let r = expected.values[i * n + j]
                let matches = r.isFinite ? abs(values[i][j] - r) <= 1e-9 * max(1, abs(r)) : values[i][j] == r
                #expect(matches, "dcGD[\(i),\(j)]: \(values[i][j]) vs \(r)")
                asymmetric = asymmetric || (r.isFinite && abs(values[i][j] - values[j][i]) > 1e-9)
            }
        }
        #expect(asymmetric)
        #expect(result.pairwiseValues.count == n * (n - 1))
        #expect(result.heatmapData.values.count == n * n)
        #expect(result.methods.contains("read from row to column"))
    }

    // MARK: - Specs and figures

    @Test func dcgdNeedsAnAxisAndIsNeverTheSeparation() throws {
        let dataset = try gravity()
        #expect(throws: IBDAnalysis.Failure.needsAxis) {
            try IBDAnalysis(spec: IBDSpec(genetic: DistanceSpec(measure: .dcgd, level: Self.population)),
                            dataset: dataset)
        }
        #expect(throws: IBDAnalysis.Failure.directedSeparation) {
            try IBDAnalysis(spec: IBDSpec(genetic: DistanceSpec(measure: .nei, level: Self.population),
                                          against: .dcgd), dataset: dataset)
        }
        #expect(DistanceOptions(dataset: dataset).measures(at: Self.population).contains(.dcgd))
    }

    @Test func aDirectionalSpecSurvivesItsJSON() throws {
        let f = try fixture().gravity
        let spec = IBDSpec(genetic: DistanceSpec(measure: .dcgd, level: Self.population),
                           axis: IBDSpec.Axis(source: .positions, name: "Deme", positions: f.axis), gamma: 1)
        let result = try run(spec, try gravity())
        let decoded = try JSONDecoder().decode(IBDSpec.self, from: Data(result.spec.json.utf8))
        #expect(decoded == result.spec)
        #expect(decoded.gamma == 1 && decoded.alongAxis && decoded.result?.isDirectional == true)
        #expect(!result.spec.json.contains(#""separation""#))
        #expect(result.spec.json.contains(#""alongAxis":true"#) && result.spec.json.contains(#""gamma":1"#))

        // Specs written before axes read as before: no axis, great-circle separation and the default γ.
        let old = #"{"genetic":{"level":"Population","measure":"nei"},"logSeparation":false,"method":"pearson","#
            + #""permutations":0,"transform":"none"}"#
        let legacy = try JSONDecoder().decode(IBDSpec.self, from: Data(old.utf8))
        #expect(legacy.axis == nil && !legacy.alongAxis && legacy.against == .greatCircle && legacy.gamma == 0.5)
        #expect(!legacy.json.contains("gamma") && !legacy.json.contains("axis"))
    }

    @Test func aSavedDirectionalAnalysisKeepsBothDirections() async throws {
        let f = try fixture().gravity
        let spec = IBDSpec(genetic: DistanceSpec(measure: .dcgd, level: Self.population),
                           axis: IBDSpec.Axis(source: .positions, name: "Deme", positions: f.axis),
                           permutations: f.nperm, seed: f.seed)
        let result = try run(spec, try gravity())
        let figure = StoredFigure(title: result.title, legend: result.legend, source: "test", result: result,
                                  image: nil, thumbnail: nil)
        #expect(result.title == "Directional isolation by graph distance among Population")
        #expect(figure.table?.columnNames == ["From", "To", "axis_difference", "dcgd", "Direction"])
        #expect(figure.rCode?.contains(#"linetype = "dashed""#) == true)
        let scatter = try #require(figure.ibdScatter)
        #expect(scatter.series.map(\.name) == ["Forward", "Reverse"])
        #expect(scatter.series.map(\.points.count).reduce(0, +) == f.dcgd.pairs)
        #expect(scatter.series.first?.line?.slope == result.spec.result?.forwardSlope)
        #expect(scatter == result.scatter)
        let table = try #require(result.spec.resultsTable)
        #expect(table.displayTexts("Statistic").suffix(7) == ["Ordered pairs", "Adjusted R² (dcGD)", "ΔR²",
                                                              "Forward slope", "Reverse slope", "Slope ratio",
                                                              "Intercept (dcGD)"])

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).gstudio")
        defer { try? FileManager.default.removeItem(at: url) }
        try await ProjectStore.saveSnapshot(figures: [figure], projectName: "dcgd", to: url)
        let loaded = try await ProjectStore.loadSnapshot(from: url).figures
        #expect(loaded.first?.ibdSpec == result.spec && loaded.first?.ibdScatter == scatter)
    }
}
