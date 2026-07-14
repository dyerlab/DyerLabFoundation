//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  NullDistributionResultTests.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//
//  Direct, hand-computed tests for pValue(direction:) — the shared logic
//  behind both rarefaction's CDF-position reading and AMOVA's permutation
//  p-value, so it deserves its own coverage rather than only being exercised
//  indirectly through those two call sites.

import Testing
import Matrix
@testable import PopulationGenetics

struct NullDistributionResultTests {

    // values = 1...10, observed = 9.
    //   >= 9: {9, 10}  -> (2+1)/11 = 3/11
    //   <= 9: {1..9}   -> (9+1)/11 = 10/11
    //   two-tailed: 2 * min(3/11, 10/11) = 6/11 (no capping needed)
    private let uncappedResult = NullDistributionResult(
        analysisType: .amovaPhiST, observed: 9.0, values: (1...10).map(Double.init)
    )

    @Test func greaterOrEqualCountsUpperTail() async throws {
        #expect(abs(uncappedResult.pValue(direction: .greaterOrEqual) - 3.0/11.0) < 1e-12)
    }

    @Test func lessOrEqualCountsLowerTail() async throws {
        #expect(abs(uncappedResult.pValue(direction: .lessOrEqual) - 10.0/11.0) < 1e-12)
    }

    @Test func greaterOrEqualIsTheDefaultDirection() async throws {
        #expect(uncappedResult.pValue() == uncappedResult.pValue(direction: .greaterOrEqual))
    }

    @Test func notEqualToDoublesTheSmallerOneSidedTail() async throws {
        #expect(abs(uncappedResult.pValue(direction: .notEqualTo) - 6.0/11.0) < 1e-12)
    }

    @Test func notEqualToCapsAtOne() async throws {
        // observed = 5: >= 5 -> {5..10} (6+1)/11 = 7/11; <= 5 -> {1..5} (5+1)/11 = 6/11.
        // 2 * min(7/11, 6/11) = 12/11 > 1.0, must cap.
        let result = NullDistributionResult(
            analysisType: .amovaPhiST, observed: 5.0, values: (1...10).map(Double.init)
        )
        #expect(result.pValue(direction: .notEqualTo) == 1.0)
    }

    @Test func emptyValuesProducesNaN() async throws {
        let result = NullDistributionResult(analysisType: .amovaPhiST, observed: 5.0, values: [])
        #expect(result.pValue().isNaN)
        #expect(result.pValue(direction: .lessOrEqual).isNaN)
        #expect(result.pValue(direction: .notEqualTo).isNaN)
    }

    @Test func pValueIsWithinValidRangeWhenNotEmpty() async throws {
        for direction: NullDistributionResult.ComparisonDirection in [.greaterOrEqual, .lessOrEqual, .notEqualTo] {
            let p = uncappedResult.pValue(direction: direction)
            #expect(p > 0.0 && p <= 1.0)
        }
    }

    @Test func equatableComparesAllFields() async throws {
        let a = NullDistributionResult(analysisType: .rarefaction(.A), observed: 3.0, values: [1, 2, 3], size: 10, seed: 42)
        let b = NullDistributionResult(analysisType: .rarefaction(.A), observed: 3.0, values: [1, 2, 3], size: 10, seed: 42)
        let c = NullDistributionResult(analysisType: .rarefaction(.Ae), observed: 3.0, values: [1, 2, 3], size: 10, seed: 42)
        #expect(a == b)
        #expect(a != c)
    }
}
