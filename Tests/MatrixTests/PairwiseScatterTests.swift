//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PairwiseScatterTests.swift
//  MatrixTests
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Testing
@testable import Matrix

struct PairwiseScatterTests {

    private let line: [[Double]] = (0..<4).map { i in (0..<4).map { j in Double(abs(i - j)) } }

    @Test func leastSquaresRecoversAnExactLine() throws {
        let x: [Double] = [0, 1, 2, 5]
        let fit = try #require(RegressionLine(leastSquaresOf: x.map { 2 + 3 * $0 }, on: x))
        #expect(abs(fit.intercept - 2) < 1e-12)
        #expect(abs(fit.slope - 3) < 1e-12)
        #expect(abs(fit.value(at: 10) - 32) < 1e-12)
    }

    @Test func leastSquaresNeedsAVaryingPredictor() {
        #expect(RegressionLine(leastSquaresOf: [1, 2, 3], on: [4, 4, 4]) == nil)
        #expect(RegressionLine(leastSquaresOf: [1], on: [1]) == nil)
        #expect(RegressionLine(leastSquaresOf: [1, 2], on: [1, 2, 3]) == nil)
    }

    @Test func mantelPointsCarryNamesAndValues() throws {
        let response = line.map { $0.map { 1 + 2 * $0 } }
        let analysis = try #require(MantelAnalysis(response: response, predictor: line,
                                                   names: ["a", "b", "c", "d"]))
        let outcome = try #require(analysis.run(options: AnalysisOptions(iterations: 0)))
        #expect(outcome.pairCount == 6)
        #expect(outcome.points.first == PairwisePoint(from: "a", to: "b", x: 1, y: 3))
        #expect(outcome.points.allSatisfy { $0.y == 1 + 2 * $0.x })
        #expect(outcome.line.map { abs($0.slope - 2) < 1e-12 } == true)

        let scatter = outcome.scatter(xLabel: "Distance", yLabel: "Genetic")
        #expect(scatter.series.count == 1)
        #expect(scatter.points == outcome.points)
        #expect(scatter.series[0].line == outcome.line)
    }

    @Test func mantelNumbersUnnamedUnits() throws {
        let outcome = try #require(MantelAnalysis(response: line, predictor: line)?
            .run(options: AnalysisOptions(iterations: 0)))
        #expect(Set(outcome.points.flatMap { [$0.from, $0.to] }) == ["1", "2", "3", "4"])
        #expect(MantelAnalysis(response: line, predictor: line, names: ["a"]) == nil)
    }
}
