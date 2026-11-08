//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IBDTests.swift
//  PopulationGeneticsTests
//
//  Isolation by distance against vegan::mantel() and lm() (Fixtures/generate_distance_fixtures.R), and a saved
//  analysis as one figure that keeps its plot, table and spec.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix
import PresentationZen
import Testing
@testable import PopulationGenetics

private struct IBDCase: Decodable {
    let method: String
    let seed: UInt64
    let permutations: Int
    let r: Double
    let p: Double
    let intercept: Double
    let slope: Double
    let r2: Double
    let pairs: Int
}

private struct IBDCases: Decodable {
    let rousset: IBDCase
    let nei: IBDCase
    let bray: IBDCase
}

private struct IBDFixtures: Decodable {
    let ibd: IBDCases
}

struct IBDTests {

    private func cases() throws -> IBDCases {
        try DistanceFixtureData.decoder.decode(IBDFixtures.self, from: Data(contentsOf: DistanceFixtureData.url)).ibd
    }

    private func run(_ genetic: DistanceSpec, logSeparation: Bool, _ fixture: IBDCase) throws -> IBDResult {
        let spec = IBDSpec(genetic: genetic, logSeparation: logSeparation,
                           method: try #require(CorrelationMethod(rawValue: fixture.method)),
                           permutations: fixture.permutations, seed: fixture.seed)
        return try #require(try IBDAnalysis(spec: spec, dataset: DistanceFixtureData.completeArapat()).run())
    }

    private func expectMatches(_ result: IBDResult, _ fixture: IBDCase, sourceLocation: SourceLocation = #_sourceLocation) {
        let summary = result.spec.result
        func close(_ a: Double?, _ b: Double) -> Bool { a.map { abs($0 - b) <= 1e-9 * max(1, abs(b)) } ?? false }
        #expect(close(summary?.r, fixture.r), "r", sourceLocation: sourceLocation)
        #expect(close(summary?.p, fixture.p), "P", sourceLocation: sourceLocation)
        #expect(close(summary?.slope, fixture.slope), "slope", sourceLocation: sourceLocation)
        #expect(close(summary?.intercept, fixture.intercept), "intercept", sourceLocation: sourceLocation)
        #expect(close(summary?.r2, fixture.r2), "R²", sourceLocation: sourceLocation)
        #expect(summary?.pairs == fixture.pairs, sourceLocation: sourceLocation)
    }

    // MARK: - Against vegan

    @Test func roussetMatchesVegan() throws {
        let fixture = try cases().rousset
        let result = try run(DistanceSpec(measure: .phiST, level: "Population"), logSeparation: true, fixture)
        #expect(result.spec.validTransform == .rousset)
        expectMatches(result, fixture)
        #expect(result.report.methods.contains("Rousset (1997)") && result.report.results.contains("Mantel r"))
        #expect(result.scatter.yLabel == "Φ_ST / (1 − Φ_ST)" && result.scatter.xLabel == "ln great-circle distance (km)")
    }

    @Test func otherMeasuresAreTestedAsTheyAre() throws {
        let fixture = try cases().nei
        let result = try run(DistanceSpec(measure: .nei, level: "Population"), logSeparation: false, fixture)
        #expect(result.spec.validTransform == .none)
        expectMatches(result, fixture)
        #expect(result.report.methods.contains("Nei's distance") && result.report.methods.contains("Spearman"))
    }

    @Test func individualsMatchVegan() throws {
        let fixture = try cases().bray
        expectMatches(try run(DistanceSpec(measure: .bray), logSeparation: false, fixture), fixture)
    }

    // MARK: - Failures

    @Test func sharedLocationsHaveNoLogarithm() throws {
        let spec = IBDSpec(genetic: DistanceSpec(measure: .amova), logSeparation: true)
        #expect(throws: IBDAnalysis.Failure.sharedLocations) {
            try IBDAnalysis(spec: spec, dataset: DistanceFixtureData.completeArapat())
        }
        #expect(throws: IBDAnalysis.Failure.noGeneticDistances) {
            try IBDAnalysis(spec: IBDSpec(genetic: DistanceSpec(measure: .greatCircle, level: "Population")),
                            dataset: DistanceFixtureData.completeArapat())
        }
    }

    @Test func stoppingTheTestReturnsNothing() throws {
        let spec = IBDSpec(permutations: 99, seed: 1)
        let analysis = try IBDAnalysis(spec: spec, dataset: DistanceFixtureData.completeArapat())
        var seen = 0
        #expect(analysis.run { done, _ in seen = done; return done < 10 } == nil)
        #expect(seen == 10)
    }

    // MARK: - Saving

    @Test func aSavedAnalysisKeepsItsPlotTableAndSpec() async throws {
        let fixture = try cases().rousset
        let result = try run(DistanceSpec(measure: .phiST, level: "Population"), logSeparation: true, fixture)
        let figure = StoredFigure(title: result.title, legend: result.legend, source: "test", result: result,
                                  image: Data([1]), thumbnail: Data([2]))
        #expect(figure.formName == "scatter" && figure.generator == .ibdAnalysis)
        #expect(figure.ibdSpec == result.spec)
        #expect(figure.ibdSpec?.json.contains(#""separation":{"level":"Population","measure":"great_circle","units":"km"}"#) == true)
        #expect(figure.rCode?.contains("geom_abline( intercept = ") == true)
        let scatter = try #require(figure.ibdScatter)
        #expect(scatter.points.count == fixture.pairs)
        #expect(scatter.series.first?.line?.slope == result.outcome.line?.slope)
        let table = try #require(figure.ibdSpec?.resultsTable)
        #expect(table.displayTexts("Statistic") == ["Pairs", "Mantel r (Pearson product-moment)", "P", "Permutations",
                                                     "Slope", "Intercept", "R²"])

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).gstudio")
        defer { try? FileManager.default.removeItem(at: url) }
        try await ProjectStore.saveSnapshot(figures: [figure], projectName: "ibd", to: url)
        let loaded = try await ProjectStore.loadSnapshot(from: url).figures
        #expect(loaded.first?.ibdSpec == result.spec && loaded.first?.ibdScatter?.points.count == fixture.pairs)
    }
}
