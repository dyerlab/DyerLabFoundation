//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IsolationByDistanceTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
import Matrix
@testable import PopulationGenetics

private enum TestKind: PairwiseMeasure {
    static let columnName = "Test"
}

struct IsolationByDistanceTests {

    private let names = ["P1", "P2", "P3", "P4", "P5"]

    /// Strata on a line at 10, 20, 40, 70, 110 km; F rises with distance.
    private func matrices(separationOrder: [String]? = nil) -> (DistanceMatrix<TestKind>, DistanceMatrix<TestKind>) {
        let position: [String: Double] = ["P1": 10, "P2": 20, "P3": 40, "P4": 70, "P5": 110]
        var f = DistanceMatrix<TestKind>(groupNames: names)
        for i in 0..<5 {
            for j in (i + 1)..<5 {
                f[i, j] = abs(position[names[i]]! - position[names[j]]!) / 250 + Double(i + j) / 1000
            }
        }
        let order = separationOrder ?? names
        var km = DistanceMatrix<TestKind>(groupNames: order)
        for i in 0..<5 {
            for j in (i + 1)..<5 { km[i, j] = abs(position[order[i]]! - position[order[j]]!) }
        }
        return (f, km)
    }

    /// The transformed matrices, built by hand, in `names` order.
    private func linearized(log: Bool) -> (response: [[Double]], predictor: [[Double]]) {
        let (f, km) = matrices()
        let response = (0..<5).map { i in (0..<5).map { j in i == j ? 0 : f[i, j] / (1 - f[i, j]) } }
        let predictor = (0..<5).map { i in (0..<5).map { j in i == j ? 0 : (log ? Foundation.log(km[i, j]) : km[i, j]) } }
        return (response, predictor)
    }

    @Test(arguments: [false, true])
    func matchesAMantelTestOfTheTransformedMatrices(log: Bool) throws {
        let (f, km) = matrices()
        let ibd = try #require(IsolationByDistanceAnalysis(differentiation: f, separation: km, logSeparation: log))
        let outcome = try #require(ibd.run(options: AnalysisOptions(iterations: 99, seed: 5)))

        let hand = linearized(log: log)
        let mantel = try #require(MantelAnalysis(response: hand.response, predictor: hand.predictor,
                                                 names: names, tag: AnalysisType.isolationByDistance.tag))
        let expected = try #require(mantel.run(options: AnalysisOptions(iterations: 99, seed: 5)))

        #expect(outcome.analysisType == .isolationByDistance)
        #expect(outcome.statistic == expected.r)
        #expect(outcome.distribution == expected.distribution)
        #expect(outcome.slope == expected.line?.slope)
        #expect(outcome.scatter.points == expected.points)
    }

    @Test func separationIsMatchedByStratumName() throws {
        let (f, km) = matrices()
        let (_, shuffled) = matrices(separationOrder: ["P4", "P1", "P5", "P3", "P2"])
        let options = AnalysisOptions(iterations: 50, seed: 1)
        let a = try #require(IsolationByDistanceAnalysis(differentiation: f, separation: km)?.run(options: options))
        let b = try #require(IsolationByDistanceAnalysis(differentiation: f, separation: shuffled)?.run(options: options))
        #expect(a.distribution == b.distribution)
    }

    @Test func pairsWithFOfOneAreLeftOut() throws {
        var (f, km) = matrices()
        f[0, 4] = 1
        let outcome = try #require(IsolationByDistanceAnalysis(differentiation: f, separation: km)?
            .run(options: AnalysisOptions(iterations: 0)))
        #expect(outcome.mantel.pairCount == 9)
        #expect(!outcome.scatter.points.contains { $0.from == "P1" && $0.to == "P5" })
    }

    @Test func scatterIsLabelledForTheTransform() throws {
        let (f, km) = matrices()
        let outcome = try #require(IsolationByDistanceAnalysis(differentiation: f, separation: km, logSeparation: true,
                                                               differentiationLabel: "θ",
                                                               separationLabel: "Distance (km)")?
            .run(options: AnalysisOptions(iterations: 0)))
        #expect(outcome.scatter.xLabel == "ln(Distance (km))")
        #expect(outcome.scatter.yLabel == "θ / (1 − θ)")
    }

    @Test func unusableInputGivesNil() {
        let (f, km) = matrices()
        var colocated = km
        colocated[0, 1] = 0
        #expect(IsolationByDistanceAnalysis(differentiation: f, separation: colocated, logSeparation: true) == nil)
        #expect(IsolationByDistanceAnalysis(differentiation: f, separation: colocated) != nil)
        let other = DistanceMatrix<TestKind>(groupNames: ["P1", "P2", "P3", "P4", "X"])
        #expect(IsolationByDistanceAnalysis(differentiation: f, separation: other) == nil)
    }

    // MARK: - Report

    @Test func reportDescribesTheLinearization() throws {
        let (f, km) = matrices()
        let ibd = try #require(IsolationByDistanceAnalysis(differentiation: f, separation: km, logSeparation: true,
                                                           separationLabel: "Distance (km)"))
        let run = try #require(ibd.perform(options: AnalysisOptions(iterations: 99, seed: 5)))
        #expect(!(run.report.methods + run.report.results).contains("{"))
        #expect(run.report.methods.contains("linearized as Φ_ST / (1 − Φ_ST)"))
        #expect(run.report.methods.contains("the natural log of distance (km) (the scale expected"))
        #expect(run.report.results.contains("slope = \(AnalysisReport.number(run.outcome.slope ?? .nan))"))
    }
}
