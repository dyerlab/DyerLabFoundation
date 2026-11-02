//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AnalysisFrameworkTests.swift
//  MatrixTests
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Testing
@testable import Matrix

struct AnalysisFrameworkTests {

    // Same hand-computed example as DistanceVarianceDecompositionTests:
    // two groups {0,1}, {2,3}; variance ratio 0.75.
    private let d2: [[Double]] = [
        [0, 2, 8, 8],
        [2, 0, 8, 8],
        [8, 8, 0, 2],
        [8, 8, 2, 0],
    ]

    @Test func mantelAndAMOVATakeTwoOperands() {
        #expect(AnalysisType.mantel.operands.map(\.kind) == [.pairwise, .pairwise])
        #expect(AnalysisType.amova.operands.map(\.kind) == [.pairwise, .partition])
        #expect(AnalysisType.amova.tag == AnalysisTag("amova"))
    }

    @Test func analysisTypeIdentityIsTheLabelAlone() {
        let other = AnalysisType("amova", displayName: "Something else", operands: [], usesIterations: false)
        #expect(other == .amova)
        #expect(Set([other, .amova, .mantel]).count == 2)
    }

    @Test func varianceDecompositionMatchesEngine() throws {
        let analysis = try #require(VarianceDecompositionAnalysis(squaredDistances: d2, partition: [0, 0, 1, 1]))
        let outcome = try #require(analysis.run(options: AnalysisOptions(iterations: 99, seed: 42)))
        #expect(outcome.analysisType == .amova)
        #expect(outcome.tag == AnalysisType.amova.tag)
        #expect(abs(outcome.statistic - 0.75) < 1e-12)

        let direct = DistanceVarianceDecomposition(squaredDistances: d2)
            .permutationTest(partition: [0, 0, 1, 1], iterations: 99, seed: 42, tag: AnalysisType.amova.tag)
        #expect(outcome.distribution == direct)
        #expect(outcome.pValue == direct.pValue())
        #expect(outcome.interval == nil)
    }

    @Test func zeroIterationsSkipsTheTest() throws {
        let analysis = try #require(VarianceDecompositionAnalysis(squaredDistances: d2, partition: [0, 0, 1, 1]))
        let outcome = try #require(analysis.run(options: AnalysisOptions(iterations: 0)))
        #expect(outcome.distribution == nil)
        #expect(outcome.pValue == nil)
    }

    @Test func customTagIsCarriedThrough() throws {
        let tag = AnalysisTag("custom")
        let analysis = try #require(VarianceDecompositionAnalysis(squaredDistances: d2, partition: [0, 0, 1, 1],
                                                                  tag: tag))
        let outcome = try #require(analysis.run(options: AnalysisOptions(iterations: 9)))
        #expect(outcome.tag == tag)
        #expect(outcome.distribution?.analysisType == tag)
    }

    @Test func unusableOperandsGiveNil() {
        #expect(VarianceDecompositionAnalysis(squaredDistances: [[0, 1], [1]], partition: [0, 1]) == nil)
        #expect(VarianceDecompositionAnalysis(squaredDistances: d2, partition: [0, 0, 1]) == nil)
        #expect(VarianceDecompositionAnalysis(squaredDistances: d2, partition: [0, 0, 0, 0]) == nil)
        #expect(VarianceDecompositionAnalysis(squaredDistances: d2, partition: [0, 1, 2, 3]) == nil)
    }

    @Test func outcomesAreUsableThroughTheProtocol() throws {
        let analyses: [any Analysis] = [
            try #require(VarianceDecompositionAnalysis(squaredDistances: d2, partition: [0, 0, 1, 1])),
        ]
        for analysis in analyses {
            let outcome = try #require(analysis.run(options: AnalysisOptions(iterations: 9)))
            #expect(outcome.analysisType == analysis.analysisType)
            #expect(outcome.pValue != nil)
        }
    }
}
