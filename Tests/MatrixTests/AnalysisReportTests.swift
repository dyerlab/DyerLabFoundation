//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AnalysisReportTests.swift
//  MatrixTests
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Testing
@testable import Matrix

struct AnalysisReportTests {

    /// Every placeholder in a report was filled.
    static func expectFilled(_ report: AnalysisReport, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(!report.methods.contains("{") && !report.methods.contains("}"), "\(report.methods)",
                sourceLocation: sourceLocation)
        #expect(!report.results.contains("{") && !report.results.contains("}"), "\(report.results)",
                sourceLocation: sourceLocation)
    }

    /// Distances along a line of 10 units.
    private let predictor: [[Double]] = (0..<10).map { i in (0..<10).map { j in Double(abs(i - j)) } }

    /// The predictor scaled, plus a little structured noise off the diagonal.
    private var response: [[Double]] {
        (0..<10).map { i in
            (0..<10).map { j -> Double in
                guard i != j else { return 0 }
                let noise = Double((i * j) % 3)
                return 1.5 * predictor[i][j] + noise
            }
        }
    }

    // MARK: - Template

    @Test func fillReplacesKnownKeysAndKeepsUnknownOnes() {
        let text = AnalysisReportTemplate.fill("r = {r}, {missing}; {r} again", with: ["r": "0.5"])
        #expect(text == "r = 0.5, {missing}; 0.5 again")
        #expect(AnalysisReportTemplate.fill("no keys", with: [:]) == "no keys")
        #expect(AnalysisReportTemplate.fill("open { only", with: ["x": "y"]) == "open { only")
    }

    @Test func keysAreListedOnceInOrder() {
        #expect(AnalysisReportTemplate.keys(in: "{b} {a} {b}") == ["b", "a"])
    }

    // MARK: - Formatting

    @Test func numbersUseThreeSignificantFigures() {
        #expect(AnalysisReport.number(0.75) == "0.750")
        #expect(AnalysisReport.number(0.0123) == "0.0123")
        #expect(AnalysisReport.number(12.345) == "12.3")
        #expect(AnalysisReport.number(-0.25) == "-0.250")
        #expect(AnalysisReport.number(0) == "0")
        #expect(AnalysisReport.number(.nan) == "NA")
        #expect(AnalysisReport.pValue(0.0123) == "P = 0.012")
        #expect(AnalysisReport.pValue(nil) == "not tested")
        #expect(AnalysisReport.sentenceCase("Separation (km)") == "separation (km)")
        #expect(AnalysisReport.sentenceCase("cGD") == "cGD")
    }

    @Test func noIterationsMeansNotTested() {
        #expect(AnalysisReport.permutationSentence(AnalysisOptions(iterations: 0), permuting: "x")
                == "Significance was not tested.")
        #expect(AnalysisReport.permutationSentence(AnalysisOptions(iterations: 999, seed: 3), permuting: "rows")
                .contains("999 random permutations of rows (random seed 3)"))
    }

    // MARK: - Analyses

    @Test func performMatchesRunAndReportsTheEstimates() throws {
        var mantel = try #require(MantelAnalysis(response: response, predictor: predictor))
        mantel.responseLabel = "genetic distance"
        mantel.predictorLabel = "geographic distance"
        mantel.unitLabel = "populations"
        let options = AnalysisOptions(iterations: 99, seed: 2)
        let run = try #require(mantel.perform(options: options))
        let outcome = try #require(mantel.run(options: options))

        #expect(run.outcome.r == outcome.r)
        #expect(run.outcome.distribution == outcome.distribution)
        #expect(run.report.analysisType == .mantel && run.report.tag == mantel.tag && run.report.options == options)
        Self.expectFilled(run.report)
        #expect(run.report.methods.contains("among 10 populations (45 pairs)"))
        #expect(run.report.methods.contains("99 random permutations"))
        #expect(run.report.results.contains("Mantel r = \(AnalysisReport.number(outcome.r))"))
        #expect(run.report.results.contains(AnalysisReport.pValue(outcome.pValue)))
        #expect(run.report.results.hasPrefix("Genetic distance was positively associated with geographic distance"))
    }

    @Test func aCustomTemplateIsFilledWithTheSameValues() throws {
        let mantel = try #require(MantelAnalysis(response: response, predictor: predictor))
        let template = AnalysisReportTemplate(methods: "{analysis}, {iterations} permutations",
                                              results: "r={r} {pValue} [{statistic}]")
        let run = try #require(mantel.perform(options: AnalysisOptions(iterations: 9), template: template))
        #expect(run.report.methods == "Mantel Test, 9 permutations")
        #expect(run.report.results.hasPrefix("r=\(AnalysisReport.number(run.outcome.r)) P = "))
    }

    @Test func varianceDecompositionReportsItsComponents() throws {
        let distances: [[Double]] = [[0, 4, 1, 4], [4, 0, 4, 1], [1, 4, 0, 4], [4, 1, 4, 0]]
        var amova = try #require(VarianceDecompositionAnalysis(squaredDistances: distances, partition: [0, 1, 0, 1]))
        amova.statisticLabel = "Φ_ST"
        let run = try #require(amova.perform(options: AnalysisOptions(iterations: 0)))
        Self.expectFilled(run.report)
        #expect(run.report.methods.contains("4 units") && run.report.methods.contains("2 groups"))
        #expect(run.report.methods.hasSuffix("Significance was not tested."))
        #expect(run.report.results.contains("Φ_ST = \(AnalysisReport.number(run.outcome.statistic)), not tested"))
    }

    @Test func rarefactionReportsTheSubsample() throws {
        var analysis = try #require(RarefactionAnalysis(population: Array(0..<30), size: 10) { Double(Set($0).count) })
        analysis.statisticLabel = "richness"
        let run = try #require(analysis.perform(options: AnalysisOptions(iterations: 20, seed: 1)))
        Self.expectFilled(run.report)
        #expect(run.report.methods.contains("20 random subsamples of 10 of the 30 units"))
        #expect(run.report.results.contains("richness was 10.0"))
        #expect(run.report.notes.isEmpty)
    }
}
