//
//  AMOVATests.swift
//  PopulationGenetics
//
//  Tests for distance-based AMOVA and its permutation test.
//

import Testing
@testable import PopulationGenetics

struct AMOVATests {

    // Hand-computed example: 4 units, 2 groups {0,1} and {2,3}.
    // within-group squared distance = 2 each; all between-group = 8.
    //   SS_T = (2+8+8+8+8+2)/4 = 9
    //   SS_W = 2/2 + 2/2 = 2 ; SS_A = 7
    //   MS_A = 7, MS_W = 1 ; n0 = (4 - 8/4)/1 = 2
    //   σ²_A = (7-1)/2 = 3 ; σ²_W = 1 ; Φ = 3/4 = 0.75
    private let d2: [[Double]] = [
        [0, 2, 8, 8],
        [2, 0, 8, 8],
        [8, 8, 0, 2],
        [8, 8, 2, 0],
    ]
    private let partition = [0, 0, 1, 1]

    @Test func totalSSIsComputed() async throws {
        let amova = AMOVA(squaredDistances: d2)
        #expect(abs(amova.totalSS - 9.0) < 1e-12)
    }

    @Test func decompositionMatchesHandComputation() async throws {
        let amova = AMOVA(squaredDistances: d2)
        let r = amova.decompose(partition: partition)
        #expect(abs(r.withinSS - 2.0) < 1e-12)
        #expect(abs(r.amongSS - 7.0) < 1e-12)
        #expect(r.groupCount == 2)
        #expect(r.dfAmong == 1)
        #expect(r.dfWithin == 2)
        #expect(abs(r.sigmaAmong - 3.0) < 1e-12)
        #expect(abs(r.sigmaWithin - 1.0) < 1e-12)
        #expect(abs(r.phi - 0.75) < 1e-12)
    }

    @Test func totalSSInvariantUnderPartition() async throws {
        // SS_T must not depend on the grouping.
        let amova = AMOVA(squaredDistances: d2)
        let a = amova.decompose(partition: [0, 0, 1, 1])
        let b = amova.decompose(partition: [0, 1, 0, 1])
        #expect(abs(a.totalSS - b.totalSS) < 1e-12)
        // SS_W + SS_A == SS_T for both.
        #expect(abs((a.withinSS + a.amongSS) - a.totalSS) < 1e-12)
        #expect(abs((b.withinSS + b.amongSS) - b.totalSS) < 1e-12)
    }

    @Test func noStructureGivesLowPhi() async throws {
        // Every pairwise distance equal -> no among-group component.
        let n = 6
        let flat = Array(repeating: Array(repeating: 4.0, count: n), count: n).enumerated().map { (i, row) -> [Double] in
            var r = row; r[i] = 0; return r
        }
        let amova = AMOVA(squaredDistances: flat)
        let r = amova.decompose(partition: [0, 0, 0, 1, 1, 1])
        #expect(abs(r.phi) < 1e-9)
    }

    @Test func permutationIsReproducibleAndBounded() async throws {
        let amova = AMOVA(squaredDistances: d2)
        let r1 = amova.permutationTest(partition: partition, iterations: 200, seed: 42, tag: .amovaPhiST)
        let r2 = amova.permutationTest(partition: partition, iterations: 200, seed: 42, tag: .amovaPhiST)
        #expect(abs(r1.observed - 0.75) < 1e-12)
        #expect(r1.values == r2.values)            // same seed -> identical null
        #expect(r1.pValue() == r2.pValue())
        #expect(r1.pValue() > 0.0 && r1.pValue() <= 1.0)
        #expect(r1.values.count == 200)
        #expect(r1.seed == 42)
        #expect(r1.analysisType == .amovaPhiST)
    }

    @Test func differentSeedsDifferentNull() async throws {
        let amova = AMOVA(squaredDistances: d2)
        let a = amova.permutationTest(partition: partition, iterations: 200, seed: 1, tag: .amovaPhiST)
        let b = amova.permutationTest(partition: partition, iterations: 200, seed: 2, tag: .amovaPhiST)
        #expect(a.values != b.values)
    }

    // MARK: - Streaming permutation

    @Test func streamMatchesBatchResult() async throws {
        let amova = AMOVA(squaredDistances: d2)
        var last: AMOVAPermutationProgress?
        var emissions = 0
        for await p in amova.permutationProgress(partition: partition, iterations: 200, seed: 42) {
            last = p
            emissions += 1
        }
        // Same seed -> identical sequence -> identical final p-value as the batch call.
        let batch = amova.permutationTest(partition: partition, iterations: 200, seed: 42, tag: .amovaPhiST)
        #expect(emissions == 200)
        #expect(last?.iteration == 200)
        #expect(abs((last?.observedRatio ?? -1) - 0.75) < 1e-12)
        #expect(abs((last?.pValue ?? -1) - batch.pValue()) < 1e-12)
    }

    @Test func streamBatchingEmitsFewerSnapshots() async throws {
        let amova = AMOVA(squaredDistances: d2)
        var emissions = 0
        var last: AMOVAPermutationProgress?
        for await p in amova.permutationProgress(partition: partition, iterations: 100, seed: 7, emitEvery: 10) {
            last = p
            emissions += 1
        }
        #expect(emissions == 10)
        #expect(last?.iteration == 100)
        #expect((last?.pValue ?? -1) > 0.0 && (last?.pValue ?? -1) <= 1.0)
    }

    @Test func streamRunningPValueIsMonotonicInExceedances() async throws {
        // Running mean Φ should stay within [0,1]-ish and iterations strictly increase.
        let amova = AMOVA(squaredDistances: d2)
        var previousIteration = 0
        for await p in amova.permutationProgress(partition: partition, iterations: 50, seed: 99) {
            #expect(p.iteration > previousIteration)
            previousIteration = p.iteration
            #expect(p.exceedances <= p.iteration)
        }
        #expect(previousIteration == 50)
    }
}
