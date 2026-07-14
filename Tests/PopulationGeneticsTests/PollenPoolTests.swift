//
//  PollenPoolTests.swift
//  PopulationGenetics
//
//  Tests for paternal-gamete recovery and pollen-pool frequency accumulation.
//

import Testing
@testable import PopulationGenetics

struct PollenPoolTests {

    // MARK: - Paternal gamete recovery

    @Test func paternalResolvedWhenOneAlleleNotMaternal() async throws {
        // offspring {1,2}, mother {1,3}: 1 is maternal, 2 is paternal.
        #expect(paternalGamete(offspring: (1, 2), mother: (1, 3)) == .resolved(2))
        // order independence
        #expect(paternalGamete(offspring: (2, 1), mother: (3, 1)) == .resolved(2))
    }

    @Test func paternalResolvedHomozygousOffspring() async throws {
        // offspring {1,1}, mother {1,3}: dad contributed 1.
        #expect(paternalGamete(offspring: (1, 1), mother: (1, 3)) == .resolved(1))
    }

    @Test func paternalResolvedHomozygousMother() async throws {
        // offspring {1,2}, mother {2,2}: 2 maternal, 1 paternal.
        #expect(paternalGamete(offspring: (1, 2), mother: (2, 2)) == .resolved(1))
    }

    @Test func paternalAmbiguousWhenOffspringMatchesMaternalHet() async throws {
        // offspring {1,2}, mother {1,2}: dad could be 1 or 2.
        #expect(paternalGamete(offspring: (1, 2), mother: (1, 2)) == .ambiguous(1, 2))
    }

    @Test func paternalImpossibleWhenNoMaternalAllele() async throws {
        // offspring {1,2}, mother {3,4}: neither offspring allele is maternal.
        #expect(paternalGamete(offspring: (1, 2), mother: (3, 4)) == .impossible)
        // homozygous offspring with no match
        #expect(paternalGamete(offspring: (1, 1), mother: (3, 4)) == .impossible)
    }

    @Test func paternalMissingOnIncompleteGenotypes() async throws {
        #expect(paternalGamete(offspring: (0, 2), mother: (1, 3)) == .missing)
        #expect(paternalGamete(offspring: (1, 2), mother: (0, 0)) == .missing)
    }

    @Test func paternalGameteFromColumn() async throws {
        let book = AlleleCodebook(alleles: ["A", "B", "C"]) // 1,2,3
        // ordinal 0 = offspring {1,2}, ordinal 1 = mother {1,3}
        let column = MultiallelicColumn(codebook: book, left: [1, 1], right: [2, 3])
        let c = paternalGamete(offspringOrdinal: 0, motherOrdinal: 1, in: column)
        #expect(c == .resolved(2))
    }

    // MARK: - Pollen-pool accumulation

    @Test func pollenPoolResolvedCounts() async throws {
        let book = AlleleCodebook(alleles: ["A", "B", "C"]) // 1,2,3
        var pool = PollenPoolFrequencies(codebook: book)
        // Three offspring of mother {1,1}: paternal gametes 2, 2, 3.
        pool.add(offspring: (1, 2), mother: (1, 1))
        pool.add(offspring: (1, 2), mother: (1, 1))
        pool.add(offspring: (1, 3), mother: (1, 1))

        #expect(pool.nResolved == 3.0)
        #expect(pool.N == 3.0)
        #expect(pool.count(forIndex: 2) == 2.0)
        #expect(pool.count(forIndex: 3) == 1.0)
        #expect(abs(pool.frequency(forIndex: 2) - 2.0 / 3.0) < 1e-12)
    }

    @Test func pollenPoolAmbiguousSplitsHalf() async throws {
        let book = AlleleCodebook(alleles: ["A", "B"]) // 1,2
        var pool = PollenPoolFrequencies(codebook: book)
        // offspring {1,2} from mother {1,2}: ambiguous -> 0.5 to each.
        pool.add(offspring: (1, 2), mother: (1, 2))

        #expect(pool.nAmbiguous == 1.0)
        #expect(pool.count(forIndex: 1) == 0.5)
        #expect(pool.count(forIndex: 2) == 0.5)
        #expect(pool.N == 1.0)
        #expect(pool.frequency(forIndex: 1) == 0.5)
    }

    @Test func pollenPoolTalliesImpossibleAndMissing() async throws {
        let book = AlleleCodebook(alleles: ["A", "B", "C"])
        var pool = PollenPoolFrequencies(codebook: book)
        pool.add(offspring: (1, 2), mother: (3, 3))   // impossible
        pool.add(offspring: (0, 2), mother: (1, 1))   // missing
        pool.add(offspring: (1, 2), mother: (1, 1))   // resolved 2

        #expect(pool.nImpossible == 1.0)
        #expect(pool.nMissing == 1.0)
        #expect(pool.nResolved == 1.0)
        #expect(pool.N == 1.0)                         // only the resolved gamete counts
        #expect(pool.count(forIndex: 2) == 1.0)
    }

    @Test func pollenPoolDiversity() async throws {
        let book = AlleleCodebook(alleles: ["A", "B"]) // 1,2
        var pool = PollenPoolFrequencies(codebook: book)
        // Two paternal gametes: one allele 1, one allele 2 -> p = q = 0.5.
        pool.add(offspring: (1, 1), mother: (1, 1))    // resolved 1
        pool.add(offspring: (1, 2), mother: (1, 1))    // resolved 2

        #expect(pool.N == 2.0)
        #expect(abs(pool.He - 0.5) < 1e-12)
        #expect(abs(pool.Ae - 2.0) < 1e-12)
        #expect(pool.frequencies() == [0.5, 0.5])
    }
}
