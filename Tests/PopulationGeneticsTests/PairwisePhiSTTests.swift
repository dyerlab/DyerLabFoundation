//
//  PairwisePhiSTTests.swift
//  PopulationGenetics
//
//  Tests for GeneticDistanceMatrix.submatrix, PhiSTMatrix, and pairwisePhiST.
//

import Testing
@testable import PopulationGenetics

struct PairwisePhiSTTests {

    // 6 units, 3 strata {A: 0,1} {B: 2,3} {C: 4,5}.
    // Within every stratum: distance 2. Between A&B and A&C: distance 8
    // (the AMOVATests.decompositionMatchesHandComputation fixture, hand-
    // verified there to give Phi = 0.75). Between B&C: distance 2, same as
    // within — no group signal, so Phi = 0 (the AMOVATests.noStructureGivesLowPhi
    // pattern). Gives two known non-trivial values and one known zero,
    // computed independently of each other.
    private func makeDistance() -> GeneticDistanceMatrix {
        var d = GeneticDistanceMatrix(count: 6)
        let within: [(Int, Int)] = [(0, 1), (2, 3), (4, 5)]
        for (i, j) in within { d[i, j] = 2 }
        for a in [0, 1] {
            for b in [2, 3] { d[a, b] = 8 }
            for c in [4, 5] { d[a, c] = 8 }
        }
        for b in [2, 3] {
            for c in [4, 5] { d[b, c] = 2 }
        }
        return d
    }

    private let strata = ["A", "A", "B", "B", "C", "C"]

    @Test func submatrixGathersArbitraryIndicesRegardlessOfOrder() async throws {
        let d = makeDistance()
        // Scattered, unsorted indices: individuals 4, 0, 3.
        let sub = d.submatrix(indices: [4, 0, 3])
        #expect(sub.count == 3)
        #expect(sub[0, 1] == d[4, 0])
        #expect(sub[0, 2] == d[4, 3])
        #expect(sub[1, 2] == d[0, 3])
    }

    @Test func submatrixDiagonalIsZero() async throws {
        let d = makeDistance()
        let sub = d.submatrix(indices: [1, 3, 5])
        #expect(sub[0, 0] == 0)
        #expect(sub[1, 1] == 0)
        #expect(sub[2, 2] == 0)
    }

    @Test func pairwisePhiSTMatchesHandComputedValues() async throws {
        let result = pairwisePhiST(distance: makeDistance(), strata: strata)
        #expect(result.groupNames == ["A", "B", "C"])
        #expect(abs(result["A", "B"]! - 0.75) < 1e-12)
        #expect(abs(result["A", "C"]! - 0.75) < 1e-12)
        #expect(abs(result["B", "C"]!) < 1e-9)
    }

    @Test func pairwisePhiSTAgreesWithDirectTwoGroupAMOVA() async throws {
        // Cross-check: the A-vs-B entry must equal calling AMOVA directly on
        // just those 4 individuals' submatrix — proving the gather-and-
        // decompose path isn't silently using the wrong individuals.
        let d = makeDistance()
        let result = pairwisePhiST(distance: d, strata: strata)
        let direct = AMOVA(distance: d.submatrix(indices: [0, 1, 2, 3])).decompose(partition: [0, 0, 1, 1]).phi
        #expect(abs(result["A", "B"]! - direct) < 1e-12)
    }

    @Test func matrixIsSymmetricByIndex() async throws {
        let result = pairwisePhiST(distance: makeDistance(), strata: strata)
        #expect(result[0, 1] == result[1, 0])
        #expect(result[0, 2] == result[2, 0])
        #expect(result[1, 2] == result[2, 1])
    }

    @Test func diagonalIsZero() async throws {
        let result = pairwisePhiST(distance: makeDistance(), strata: strata)
        #expect(result[0, 0] == 0)
        #expect(result[1, 1] == 0)
        #expect(result[2, 2] == 0)
    }

    @Test func groupNamesAreNaturallySorted() async throws {
        // Numeric-looking labels should sort numerically, not lexicographically.
        var d = GeneticDistanceMatrix(count: 6)
        for i in 0..<6 { for j in (i + 1)..<6 { d[i, j] = 4 } }
        let result = pairwisePhiST(distance: d, strata: ["9", "9", "12", "12", "88", "88"])
        #expect(result.groupNames == ["9", "12", "88"])
    }

    @Test func nameSubscriptReturnsNilForUnknownStratum() async throws {
        let result = pairwisePhiST(distance: makeDistance(), strata: strata)
        #expect(result["A", "Nonexistent"] == nil)
    }

    @Test func singleStratumProducesEmptyMatrixWithoutCrashing() async throws {
        let result = pairwisePhiST(distance: makeDistance(), strata: Array(repeating: "OnlyOne", count: 6))
        #expect(result.groupNames == ["OnlyOne"])
        #expect(result[0, 0] == 0)
    }

    @Test func denseIsSymmetricWithZeroDiagonal() async throws {
        let result = pairwisePhiST(distance: makeDistance(), strata: strata)
        let dense = result.dense()
        #expect(dense[0][1] == dense[1][0])
        #expect(dense[0][0] == 0)
    }
}
