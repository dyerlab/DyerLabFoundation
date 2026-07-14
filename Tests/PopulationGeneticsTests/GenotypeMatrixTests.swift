//
//  GenotypeMatrixTests.swift
//  PopulationGenetics
//
//  Tests for the GenotypeMatrix container and its per-locus reductions.
//

import Testing
@testable import PopulationGenetics

struct GenotypeMatrixTests {

    /// Builds a 4-individual matrix with one biallelic SNP and one microsat locus.
    private func makeMatrix() -> GenotypeMatrix {
        let individuals = [
            Individual(name: "i0"),
            Individual(name: "i1"),
            Individual(name: "i2"),
            Individual(name: "i3"),
        ]

        let snpBook = AlleleCodebook(alleles: ["G", "A"])           // 1 = G, 2 = A
        // AA, AB, BB, missing
        let snp = BiallelicColumn(codebook: snpBook, codes: [1, 2, 3, 0])

        let msatBook = AlleleCodebook(alleles: ["142", "146", "150"]) // 1,2,3
        let msat = MultiallelicColumn(
            codebook: msatBook,
            left:  [1, 2, 1, 0],
            right: [1, 3, 2, 0]
        )

        let loci = [
            Locus(name: "snp1", location: 100, contig: "1"),
            Locus(name: "mp20", location: 0, contig: "0"),
        ]

        return GenotypeMatrix(individuals: individuals, loci: loci, columns: [snp, msat])
    }

    @Test func shapeAndCounts() async throws {
        let m = makeMatrix()
        #expect(m.individualCount == 4)
        #expect(m.locusCount == 2)
        #expect(m.locusIndex(named: "mp20") == 1)
        #expect(m.locusIndex(named: "absent") == nil)
        #expect(m.column(named: "snp1")?.markerType == .biallelicSNP)
    }

    @Test func perLocusFrequenciesAllIndividuals() async throws {
        let m = makeMatrix()
        // SNP: AA, AB, BB, missing -> ref=3, alt=3, N=6, 1 het, 3 genos
        let snp = m.frequencies(atLocus: 0)
        #expect(snp.N == 6.0)
        #expect(snp.count(forIndex: 1) == 3.0)
        #expect(snp.count(forIndex: 2) == 3.0)
        #expect(snp.numHets == 1.0)
        #expect(abs(snp.He - 0.5) < 1e-12)
    }

    @Test func namedLocusFrequencies() async throws {
        let m = makeMatrix()
        // mp20 over all: (1,1),(2,3),(1,2),missing -> alleles 1:3, 2:2, 3:1, N=6
        let f = try #require(m.frequencies(forLocus: "mp20", over: 0..<m.individualCount))
        #expect(f.N == 6.0)
        #expect(f.count(forIndex: 1) == 3.0)
        #expect(f.count(forIndex: 2) == 2.0)
        #expect(f.count(forIndex: 3) == 1.0)
        #expect(f.numGenos == 3.0)   // the missing individual is skipped
    }

    @Test func reductionOverStratumSubset() async throws {
        let m = makeMatrix()
        // A "stratum" = individuals {0, 2}. SNP codes there: AA, BB.
        let snp = m.frequencies(atLocus: 0, over: [0, 2])
        #expect(snp.N == 4.0)
        #expect(snp.count(forIndex: 1) == 2.0)  // AA
        #expect(snp.count(forIndex: 2) == 2.0)  // BB
        #expect(snp.numHets == 0.0)
    }

    @Test func multilocusFrequenciesOverSubset() async throws {
        let m = makeMatrix()
        // One AlleleFrequencies per locus for the stratum {0,1}.
        let perLocus = m.frequencies(over: [0, 1])
        #expect(perLocus.count == 2)
        // SNP {0,1} = AA, AB -> ref=3, alt=1
        #expect(perLocus[0].count(forIndex: 1) == 3.0)
        #expect(perLocus[0].count(forIndex: 2) == 1.0)
        // mp20 {0,1} = (1,1),(2,3) -> 1:2, 2:1, 3:1
        #expect(perLocus[1].count(forIndex: 1) == 2.0)
        #expect(perLocus[1].count(forIndex: 2) == 1.0)
        #expect(perLocus[1].count(forIndex: 3) == 1.0)
    }
}
