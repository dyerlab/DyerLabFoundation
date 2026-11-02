//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RarefactionAnalysisTests.swift
//  MatrixTests
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Testing
@testable import Matrix

struct RarefactionAnalysisTests {

    private let sample: [Double] = (1...20).map(Double.init)

    @Test func matchesTheSubsampleEngine() throws {
        let mean: @Sendable ([Double]) -> Double = { $0.reduce(0, +) / Double($0.count) }
        let analysis = try #require(RarefactionAnalysis(population: sample, size: 5, statistic: mean))
        let outcome = try #require(analysis.run(options: AnalysisOptions(iterations: 40, seed: 9)))
        let direct = Resampling.subsampleTest(population: sample, size: 5, iterations: 40, seed: 9,
                                              tag: AnalysisType.rarefaction.tag, statistic: mean)

        #expect(outcome.analysisType == .rarefaction)
        #expect(outcome.distribution == direct)
        #expect(outcome.fullSampleValue == 10.5)
        #expect(outcome.size == 5)
        #expect(abs(outcome.statistic - direct.values.reduce(0, +) / 40) < 1e-12)
        #expect(outcome.interval == empiricalQuantile(direct.values, probability: 0.025)
                ... empiricalQuantile(direct.values, probability: 0.975))
        #expect(outcome.pValue == nil)
    }

    @Test func unusableSizesGiveNil() throws {
        #expect(RarefactionAnalysis(population: sample, size: 0) { _ in 0 } == nil)
        #expect(RarefactionAnalysis(population: sample, size: 20) { _ in 0 } == nil)
        let analysis = try #require(RarefactionAnalysis(population: sample, size: 5) { $0.max() ?? 0 })
        #expect(analysis.run(options: AnalysisOptions(iterations: 0)) == nil)
    }
}
