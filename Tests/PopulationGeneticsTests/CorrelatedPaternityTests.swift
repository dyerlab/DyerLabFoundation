//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  CorrelatedPaternityTests.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 7/24/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

import XCTest
@testable import PopulationGenetics

final class CorrelatedPaternityTests: XCTestCase {

    // MARK: - matchProbability

    func testMatchProbabilityResolvedPair() {
        XCTAssertEqual(GenotypeMatrix.matchProbability(.resolved(1), .resolved(1)), 1.0)
        XCTAssertEqual(GenotypeMatrix.matchProbability(.resolved(1), .resolved(2)), 0.0)
    }

    func testMatchProbabilityResolvedAndAmbiguous() {
        // Resolved allele 1 is one of the ambiguous candidates: half-credit.
        XCTAssertEqual(GenotypeMatrix.matchProbability(.resolved(1), .ambiguous(1, 2)), 0.5)
        XCTAssertEqual(GenotypeMatrix.matchProbability(.ambiguous(1, 2), .resolved(1)), 0.5)
        // Resolved allele 3 matches neither candidate.
        XCTAssertEqual(GenotypeMatrix.matchProbability(.resolved(3), .ambiguous(1, 2)), 0.0)
    }

    func testMatchProbabilityAmbiguousPair() {
        // One shared candidate out of four cross combinations.
        XCTAssertEqual(GenotypeMatrix.matchProbability(.ambiguous(1, 2), .ambiguous(2, 3)), 0.25)
        // Identical candidate sets: two of four combinations match (1==1, 2==2).
        XCTAssertEqual(GenotypeMatrix.matchProbability(.ambiguous(1, 2), .ambiguous(1, 2)), 0.5)
        // No shared candidates.
        XCTAssertEqual(GenotypeMatrix.matchProbability(.ambiguous(1, 2), .ambiguous(3, 4)), 0.0)
    }

    func testMatchProbabilityUninformativePairsReturnNil() {
        XCTAssertNil(GenotypeMatrix.matchProbability(.missing, .resolved(1)))
        XCTAssertNil(GenotypeMatrix.matchProbability(.impossible, .ambiguous(1, 2)))
    }

    // MARK: - End-to-end estimation

    /// Builds a single-locus, 4-allele matrix with `familyCount` families,
    /// each with a homozygous mother (allele `1`, so every offspring's
    /// paternal allele resolves unambiguously) and `paternalAlleles.count`
    /// offspring per family, whose paternal alleles are `paternalAlleles[family]`.
    private func makeSireMatrix(paternalAlleles: [[UInt8]]) -> (GenotypeMatrix, ParentageDesign) {
        var codebook = AlleleCodebook()
        codebook.register("A")
        codebook.register("B")
        codebook.register("C")
        codebook.register("D")

        var individuals: [Individual] = []
        var left: [UInt8] = []
        var right: [UInt8] = []
        var families: [MaternalFamily] = []

        for (familyIndex, sires) in paternalAlleles.enumerated() {
            individuals.append(Individual(name: "Mom\(familyIndex)"))
            let momOrdinal = individuals.count - 1
            left.append(1)
            right.append(1) // Mom is homozygous 1/1.

            var offspringOrdinals: [Int] = []
            for (n, sireAllele) in sires.enumerated() {
                individuals.append(Individual(name: "Off\(familyIndex)_\(n)"))
                offspringOrdinals.append(individuals.count - 1)
                left.append(1) // The maternally-transmitted allele.
                right.append(sireAllele) // The paternal allele.
            }
            families.append(MaternalFamily(id: "F\(familyIndex)", mother: momOrdinal, offspring: offspringOrdinals))
        }

        let column = MultiallelicColumn(codebook: codebook, left: left, right: right)
        let matrix = GenotypeMatrix(individuals: individuals, loci: [Locus(name: "L1")], columns: [column])
        return (matrix, ParentageDesign(families: families))
    }

    /// Every family's offspring all share the same (family-specific)
    /// paternal allele — a single father per family — while the alleles
    /// used differ enough across families that the pollen pool as a whole
    /// stays evenly diverse. r_p should read as (approximately) a single
    /// effective father: `r_p ≈ 1`, `effectiveNumberOfPollenDonors ≈ 1`.
    func testSingleFatherPerFamilyGivesMaximalCorrelatedPaternity() {
        let (matrix, design) = makeSireMatrix(paternalAlleles: [
            [1, 1, 1, 1],
            [2, 2, 2, 2],
            [3, 3, 3, 3],
            [4, 4, 4, 4],
        ])

        let result = matrix.correlatedPaternity(design: design)

        XCTAssertEqual(result.rp, 1.0, accuracy: 1e-9)
        XCTAssertEqual(result.effectiveNumberOfPollenDonors ?? .nan, 1.0, accuracy: 1e-9)
        XCTAssertEqual(result.informativePairCount, 4 * 6) // C(4,2) pairs per family, 4 families.
    }

    /// Every family's offspring cycle through all four alleles evenly — no
    /// father is shared by more than one sib pair within a family more
    /// often than the population's own diversity would predict by chance.
    /// r_p should read well below the single-father scenario (and can go
    /// negative, since this is an unbiased moment estimator, not a bounded one).
    func testManyFathersPerFamilyGivesLowCorrelatedPaternity() {
        let (manyFathersMatrix, manyFathersDesign) = makeSireMatrix(paternalAlleles: [
            [1, 2, 3, 4, 1, 2, 3, 4],
        ])
        // Same population-wide allele diversity (four alleles, evenly
        // represented) as the many-fathers case above, so both scenarios
        // share the same background match rate S — only the within-family
        // sharing pattern differs.
        let (singleFatherMatrix, singleFatherDesign) = makeSireMatrix(paternalAlleles: [
            [1, 1, 1, 1], [2, 2, 2, 2], [3, 3, 3, 3], [4, 4, 4, 4],
        ])

        let manyFathersResult = manyFathersMatrix.correlatedPaternity(design: manyFathersDesign)
        let singleFatherResult = singleFatherMatrix.correlatedPaternity(design: singleFatherDesign)

        XCTAssertLessThan(manyFathersResult.rp, singleFatherResult.rp)
        XCTAssertNil(manyFathersResult.effectiveNumberOfPollenDonors) // r_p <= 0 here.
    }

    func testCorrelatedPaternityPerFamilyReturnsOneResultPerFamily() {
        let (matrix, design) = makeSireMatrix(paternalAlleles: [
            [1, 1, 1, 1],
            [2, 2, 2, 2],
            [3, 3, 3, 3],
            [4, 4, 4, 4],
        ])

        let results = matrix.correlatedPaternityPerFamily(design: design)

        XCTAssertEqual(results.count, 4)
        // Each family is internally a single perfectly-matching sire, same as the pooled case.
        for result in results {
            XCTAssertEqual(result.rp, 1.0, accuracy: 1e-9)
            XCTAssertEqual(result.informativePairCount, 6)
        }
    }

    func testFamiliesWithoutAGenotypedMotherContributeNothing() {
        let (matrix, design) = makeSireMatrix(paternalAlleles: [[1, 1, 1, 1]])
        let familyWithoutMother = MaternalFamily(id: "F_no_mom", mother: nil, offspring: design.families[0].offspring)
        let mixedDesign = ParentageDesign(families: [familyWithoutMother])

        let result = matrix.correlatedPaternity(design: mixedDesign)
        XCTAssertEqual(result.informativePairCount, 0)
        XCTAssertTrue(result.rp.isNaN)
        XCTAssertNil(result.effectiveNumberOfPollenDonors)
    }
}
