//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  New coverage — `Resampling.subsampleTest` had no prior direct test
//  anywhere: in PopulationGenetics it was only exercised indirectly through
//  domain-specific Rarefaction.swift wrappers, which don't move here. This
//  also locks in the reproducibility fix (a confirmed seeding bug in the
//  pre-promotion rarefaction code) — `subsampleTest` requires a seed and
//  stores it in the result, unlike the code it replaces.
//

import Foundation
import Testing
@testable import Matrix

struct ResamplingTests {

    private let testTag = AnalysisTag("test.resampling")

    // MARK: - permutationTest

    @Test func permutationTestObservedIsUnshuffledStatistic() async throws {
        let labels = [0, 0, 0, 1, 1, 1]
        let result = Resampling.permutationTest(labels: labels, iterations: 50, seed: 1, tag: testTag) { shuffled in
            Double(shuffled.first!)
        }
        #expect(result.observed == Double(labels.first!))
    }

    @Test func permutationTestSameSeedIsReproducible() async throws {
        let labels = Array(0..<20)
        let statistic: ([Int]) -> Double = { Double($0.reduce(0, +)) }
        let a = Resampling.permutationTest(labels: labels, iterations: 100, seed: 42, tag: testTag, statistic: statistic)
        let b = Resampling.permutationTest(labels: labels, iterations: 100, seed: 42, tag: testTag, statistic: statistic)
        #expect(a.values == b.values)
    }

    @Test func permutationTestRecordsSeedAndTag() async throws {
        let result = Resampling.permutationTest(labels: [1, 2, 3], iterations: 10, seed: 7, tag: testTag) { _ in 0.0 }
        #expect(result.seed == 7)
        #expect(result.analysisType == testTag)
        #expect(result.values.count == 10)
        #expect(result.size == nil)  // permutationTest has no subsample size
    }

    // MARK: - subsampleTest

    @Test func subsampleTestDrawsExactlyTheRequestedSize() async throws {
        let population = Array(0..<100)
        let result = Resampling.subsampleTest(population: population, size: 10, iterations: 30, seed: 1, tag: testTag) { sample in
            Double(sample.count)
        }
        #expect(result.values.allSatisfy { $0 == 10.0 })
    }

    @Test func subsampleTestObservedIsFullPopulationStatistic() async throws {
        let population = Array(0..<50)
        let result = Resampling.subsampleTest(population: population, size: 5, iterations: 10, seed: 1, tag: testTag) { sample in
            Double(sample.count)
        }
        #expect(result.observed == 50.0)
    }

    @Test func subsampleTestSameSeedIsReproducible() async throws {
        let population = Array(0..<200)
        let statistic: ([Int]) -> Double = { Double($0.reduce(0, +)) }
        let a = Resampling.subsampleTest(population: population, size: 20, iterations: 50, seed: 99, tag: testTag, statistic: statistic)
        let b = Resampling.subsampleTest(population: population, size: 20, iterations: 50, seed: 99, tag: testTag, statistic: statistic)
        #expect(a.values == b.values)
    }

    @Test func subsampleTestDifferentSeedsDiffer() async throws {
        let population = Array(0..<200)
        let statistic: ([Int]) -> Double = { Double($0.reduce(0, +)) }
        let a = Resampling.subsampleTest(population: population, size: 20, iterations: 50, seed: 1, tag: testTag, statistic: statistic)
        let b = Resampling.subsampleTest(population: population, size: 20, iterations: 50, seed: 2, tag: testTag, statistic: statistic)
        #expect(a.values != b.values)
    }

    @Test func subsampleTestRecordsSizeAndSeed() async throws {
        let result = Resampling.subsampleTest(population: Array(0..<30), size: 5, iterations: 8, seed: 3, tag: testTag) { _ in 0.0 }
        #expect(result.size == 5)
        #expect(result.seed == 3)
        #expect(result.values.count == 8)
    }

    @Test func subsampleTestSupportsScaledSizeForDecomposedUnits() async throws {
        // Mirrors PopulationGenetics' allelicRarefaction, which draws
        // 2*size alleles to estimate a genotype-level metric — the engine
        // itself has no notion of that relationship, it just draws exactly
        // `size` elements of whatever `population` it's given.
        let alleles = Array(repeating: "A", count: 40) + Array(repeating: "B", count: 40)
        let nominalSize = 10
        let result = Resampling.subsampleTest(population: alleles, size: 2 * nominalSize, iterations: 20, seed: 5, tag: testTag) { sample in
            Double(sample.count)
        }
        #expect(result.values.allSatisfy { $0 == Double(2 * nominalSize) })
    }
}
