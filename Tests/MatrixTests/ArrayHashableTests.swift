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
//  Adapted from the "Array+Hashable Tests" section of PopulationGenetics'
//  ExtensionTests.swift. Renamed histogram() -> valueCounts() (collides
//  with Vector.histogram(bins:) since Vector is typealias Vector = [Double]).
//  The allele-data integration test in the original (testHistogramWithAlleleData,
//  which pulled genotypes from PopulationGeneticsPreviewData) is domain-specific
//  and stays there; the mechanical behavior it was checking (non-empty result,
//  counts sum to input length) is covered here without the domain fixture.
//

import Foundation
import Testing
@testable import Matrix

struct ArrayHashableTests {

    @Test func valueCountsWithStrings() async throws {
        let array = ["A", "B", "A", "C", "B", "A", "D"]
        let counts = array.valueCounts()

        #expect(counts["A"] == 3.0)
        #expect(counts["B"] == 2.0)
        #expect(counts["C"] == 1.0)
        #expect(counts["D"] == 1.0)
        #expect(counts.count == 4)
    }

    @Test func valueCountsWithIntegers() async throws {
        let array = [1, 2, 3, 2, 1, 2, 4]
        let counts = array.valueCounts()

        #expect(counts[1] == 2.0)
        #expect(counts[2] == 3.0)
        #expect(counts[3] == 1.0)
        #expect(counts[4] == 1.0)
    }

    @Test func valueCountsWithEmptyArray() async throws {
        let array: [String] = []
        let counts = array.valueCounts()

        #expect(counts.isEmpty)
    }

    @Test func valueCountsWithSingleElement() async throws {
        let array = ["A"]
        let counts = array.valueCounts()

        #expect(counts["A"] == 1.0)
        #expect(counts.count == 1)
    }

    @Test func valueCountsWithAllSameElements() async throws {
        let array = ["X", "X", "X", "X", "X"]
        let counts = array.valueCounts()

        #expect(counts["X"] == 5.0)
        #expect(counts.count == 1)
    }

    @Test func valueCountsSumToInputLength() async throws {
        let array = ["A", "B", "A", "C", "B", "A"]
        let counts = array.valueCounts()

        let total = counts.values.reduce(0.0, +)
        #expect(total == Double(array.count))

        // Can calculate frequencies.
        let freqA = counts["A"]! / total
        #expect(freqA == 0.5) // 3/6
    }

    @Test func valueCountsDoesNotCollideWithVectorHistogram() async throws {
        // The whole reason for the rename: Vector is `typealias Vector = [Double]`,
        // so both `valueCounts()` (this file) and `histogram(bins:)`
        // (VectorBinningTests.swift) must resolve unambiguously on the same type.
        let v: Vector = [1.0, 1.0, 2.0, 3.0]
        let counts = v.valueCounts()
        #expect(counts[1.0] == 2.0)

        let bins = v.histogram(bins: 2)
        #expect(bins.count == 2)
    }
}
