//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MantelAnalysisTests.swift
//  MatrixTests
//
//  vegan parity cases come from Fixtures/generate_mantel_fixtures.R.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import Matrix

private struct MantelFixture: Decodable {
    let n: Int
    let seed: Int
    let method: String
    let permutations: Int
    let predictor: [[Double]]
    let response: [[Double]]
    let statistic: Double
    let perm: [Double]
    let signif: Double
}

private func loadFixtures() throws -> [String: MantelFixture] {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/mantel_fixtures.json")
    return try JSONDecoder().decode([String: MantelFixture].self, from: Data(contentsOf: url))
}

private enum TestMeasure: PairwiseMeasure {
    static let columnName = "Test"
}

struct MantelAnalysisTests {

    /// Five units on a line; distances are |i − j|, response is distance squared.
    private let line: [[Double]] = (0..<5).map { i in (0..<5).map { j in Double(abs(i - j)) } }
    private var squared: [[Double]] { line.map { $0.map { $0 * $0 } } }

    // MARK: - vegan parity

    @Test(arguments: ["pearson_n12", "spearman_n12", "pearson_n25"])
    func matchesVeganPermutationByPermutation(_ name: String) throws {
        let fixture = try #require(try loadFixtures()[name])
        let method = try #require(CorrelationMethod(rawValue: fixture.method))
        let analysis = try #require(MantelAnalysis(response: fixture.response, predictor: fixture.predictor,
                                                   method: method))
        let outcome = try #require(analysis.run(options: AnalysisOptions(iterations: fixture.permutations,
                                                                         seed: UInt64(fixture.seed))))
        #expect(abs(outcome.r - fixture.statistic) < 1e-12)
        #expect(outcome.pairCount == fixture.n * (fixture.n - 1) / 2)
        let values = try #require(outcome.distribution?.values)
        #expect(values.count == fixture.perm.count)
        #expect(zip(values, fixture.perm).allSatisfy { abs($0 - $1) < 1e-12 })
        #expect(outcome.pValue == fixture.signif)
    }

    // MARK: - Pairs

    @Test func nonFiniteResponsePairsAreLeftOut() throws {
        var response = squared
        response[0][4] = .infinity
        response[4][0] = .infinity
        let analysis = try #require(MantelAnalysis(response: response, predictor: line))
        let outcome = try #require(analysis.run(options: AnalysisOptions(iterations: 0)))

        var x: [Double] = [], y: [Double] = []
        for j in 0..<5 { for i in 0..<j where !(i == 0 && j == 4) { x.append(line[i][j]); y.append(squared[i][j]) } }
        #expect(outcome.pairCount == 9)
        #expect(abs(outcome.r - pearsonCorrelation(x, y)) < 1e-12)
        #expect(outcome.distribution == nil)
    }

    @Test func spearmanIsOneForAMonotoneRelation() throws {
        let analysis = try #require(MantelAnalysis(response: squared, predictor: line, method: .spearman))
        let outcome = try #require(analysis.run(options: AnalysisOptions(iterations: 0)))
        #expect(abs(outcome.r - 1) < 1e-12)
    }

    @Test func sameSeedGivesTheSameNullDistribution() throws {
        let analysis = try #require(MantelAnalysis(response: squared, predictor: line))
        let first = analysis.run(options: AnalysisOptions(iterations: 50, seed: 11))?.distribution
        let second = analysis.run(options: AnalysisOptions(iterations: 50, seed: 11))?.distribution
        #expect(first == second)
        #expect(first?.analysisType == AnalysisType.mantel.tag)
    }

    // MARK: - Named matrices

    @Test func namedMatricesAreMatchedByName() throws {
        let names = ["a", "b", "c", "d", "e"]
        var response = DistanceMatrix<TestMeasure>(groupNames: names)
        var predictor = DistanceMatrix<TestMeasure>(groupNames: names.reversed())
        for i in 0..<5 {
            for j in (i + 1)..<5 {
                response[i, j] = squared[i][j]
                predictor[4 - i, 4 - j] = line[i][j]
            }
        }
        let named = try #require(MantelAnalysis(response: response, predictor: predictor))
        let plain = try #require(MantelAnalysis(response: squared, predictor: line))
        let options = AnalysisOptions(iterations: 20, seed: 3)
        #expect(named.run(options: options)?.distribution == plain.run(options: options)?.distribution)
    }

    @Test func differentNamesGiveNil() {
        let response = DistanceMatrix<TestMeasure>(groupNames: ["a", "b", "c", "d"])
        let predictor = DistanceMatrix<TestMeasure>(groupNames: ["a", "b", "c", "x"])
        #expect(MantelAnalysis(response: response, predictor: predictor) == nil)
    }

    // MARK: - Unusable input

    @Test func unusableMatricesGiveNil() {
        var badPredictor = line
        badPredictor[1][2] = .nan
        #expect(MantelAnalysis(response: squared, predictor: badPredictor) == nil)
        #expect(MantelAnalysis(response: squared, predictor: Array(line.prefix(4))) == nil)
        #expect(MantelAnalysis(response: [[0, 1], [1, 0]], predictor: [[0, 1], [1, 0]]) == nil)
        #expect(MantelAnalysis(response: [[0, 1, 2], [1, 0], [2, 1, 0]],
                               predictor: [[0, 1, 2], [1, 0, 1], [2, 1, 0]]) == nil)
    }
}
