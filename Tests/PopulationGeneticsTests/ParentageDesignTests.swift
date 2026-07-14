//
//  ParentageDesignTests.swift
//  PopulationGenetics
//
//  Tests for MaternalFamily / ParentageDesign and the two driving operations:
//  "all adult allele frequencies" and per-mother pollen-pool recovery.
//

import Testing
@testable import PopulationGenetics

struct ParentageDesignTests {

    /// One microsatellite locus, two families.
    /// ord 0 = mother A (1,1); ord 1,2 = offspring of A (1,2),(1,3)
    /// ord 3 = mother B (2,2); ord 4 = offspring of B (2,3)
    private func makeMatrixAndDesign() -> (GenotypeMatrix, ParentageDesign) {
        let individuals = (0..<5).map { Individual(name: "i\($0)") }
        let book = AlleleCodebook(alleles: ["A1", "A2", "A3"])   // 1,2,3
        let col = MultiallelicColumn(
            codebook: book,
            left:  [1, 1, 1, 2, 2],
            right: [1, 2, 3, 2, 3]
        )
        let loci = [Locus(name: "mp20")]
        let matrix = GenotypeMatrix(individuals: individuals, loci: loci, columns: [col])

        let design = ParentageDesign(families: [
            MaternalFamily(id: "A", mother: 0, offspring: [1, 2]),
            MaternalFamily(id: "B", mother: 3, offspring: [4]),
        ])
        return (matrix, design)
    }

    @Test func designIndexSets() async throws {
        let (_, design) = makeMatrixAndDesign()
        #expect(design.adultOrdinals == [0, 3])
        #expect(design.offspringOrdinals == [1, 2, 4])
        #expect(design.family(id: "B")?.offspring == [4])
        #expect(design.family(id: "A")?.hasMother == true)
    }

    @Test func allAdultAlleleFrequencies() async throws {
        let (matrix, design) = makeMatrixAndDesign()
        // Adults: A=(1,1), B=(2,2) -> allele 1: 2, allele 2: 2, N=4
        let f = matrix.adultFrequencies(atLocus: 0, design: design)
        #expect(f.N == 4.0)
        #expect(f.count(forIndex: 1) == 2.0)
        #expect(f.count(forIndex: 2) == 2.0)
        #expect(f.count(forIndex: 3) == 0.0)
        #expect(f.numGenos == 2.0)
    }

    @Test func pollenPoolForMotherA() async throws {
        let (matrix, design) = makeMatrixAndDesign()
        let family = try #require(design.family(id: "A"))
        // mother (1,1); offspring (1,2)->paternal 2, (1,3)->paternal 3
        let pool = matrix.pollenPool(forFamily: family, atLocus: 0)
        #expect(pool.nResolved == 2.0)
        #expect(pool.N == 2.0)
        #expect(pool.count(forIndex: 2) == 1.0)
        #expect(pool.count(forIndex: 3) == 1.0)
        #expect(pool.count(forIndex: 1) == 0.0)   // maternal allele removed
    }

    @Test func pollenPoolForMotherB() async throws {
        let (matrix, design) = makeMatrixAndDesign()
        let family = try #require(design.family(id: "B"))
        // mother (2,2); offspring (2,3) -> paternal 3
        let pool = matrix.pollenPool(forFamily: family, atLocus: 0)
        #expect(pool.nResolved == 1.0)
        #expect(pool.count(forIndex: 3) == 1.0)
        #expect(pool.count(forIndex: 2) == 0.0)
    }

    @Test func pollenPoolMissingMotherIsSkipped() async throws {
        let (matrix, _) = makeMatrixAndDesign()
        // Family with no maternal tissue: every offspring becomes "missing".
        let orphan = MaternalFamily(id: "C", mother: nil, offspring: [1, 2])
        let pool = matrix.pollenPool(forFamily: orphan, atLocus: 0)
        #expect(pool.N == 0.0)
        #expect(pool.nMissing == 2.0)
    }

    @Test func pollenPoolAllLociShape() async throws {
        let (matrix, design) = makeMatrixAndDesign()
        let family = try #require(design.family(id: "A"))
        let perLocus = matrix.pollenPool(forFamily: family)
        #expect(perLocus.count == matrix.locusCount)
        #expect(perLocus[0].nResolved == 2.0)
    }
}
