//
//  GeneticDistanceTests.swift
//  PopulationGenetics
//
//  Tests for smousePeakallSquaredDistance, GeneticDistanceMatrix,
//  and the GenotypeMatrix distance extensions.
//

import Testing
@testable import PopulationGenetics

struct GeneticDistanceTests {

    // MARK: - smousePeakallSquaredDistance

    // Canonical ladder: AA·AA=0, AA·AB=1, AA·BB=4 (Smouse & Peakall 1999).
    @Test func canonicalLadder() async throws {
        let aa: (UInt8, UInt8) = (1, 1)
        let ab: (UInt8, UInt8) = (1, 2)
        let bb: (UInt8, UInt8) = (2, 2)
        #expect(smousePeakallSquaredDistance(aa, aa) == 0.0)
        #expect(smousePeakallSquaredDistance(aa, ab) == 1.0)
        #expect(smousePeakallSquaredDistance(aa, bb) == 4.0)
        #expect(smousePeakallSquaredDistance(ab, ab) == 0.0)
        #expect(smousePeakallSquaredDistance(ab, bb) == 1.0)
    }

    @Test func distanceIsSymmetric() async throws {
        let g1: (UInt8, UInt8) = (1, 3)
        let g2: (UInt8, UInt8) = (2, 4)
        #expect(smousePeakallSquaredDistance(g1, g2) == smousePeakallSquaredDistance(g2, g1))
    }

    @Test func alleleOrderWithinGenotypeDoesNotMatter() async throws {
        let ab: (UInt8, UInt8) = (1, 2)
        let ba: (UInt8, UInt8) = (2, 1)
        let aa: (UInt8, UInt8) = (1, 1)
        #expect(smousePeakallSquaredDistance(ab, ba) == 0.0)
        #expect(smousePeakallSquaredDistance(ab, aa) == smousePeakallSquaredDistance(ba, aa))
    }

    @Test func missingFirstAlleleReturnsNil() async throws {
        let halfMissing: (UInt8, UInt8) = (0, 1)
        let aa: (UInt8, UInt8) = (1, 1)
        #expect(smousePeakallSquaredDistance(halfMissing, aa) == nil)
    }

    @Test func missingSecondAlleleReturnsNil() async throws {
        let halfMissing: (UInt8, UInt8) = (1, 0)
        let aa: (UInt8, UInt8) = (1, 1)
        #expect(smousePeakallSquaredDistance(halfMissing, aa) == nil)
    }

    @Test func bothMissingReturnsNil() async throws {
        let missing: (UInt8, UInt8) = (0, 0)
        #expect(smousePeakallSquaredDistance(missing, missing) == nil)
    }

    // MARK: - GeneticDistanceMatrix

    @Test func matrixInitializesToZero() async throws {
        let m = GeneticDistanceMatrix(count: 5)
        for i in 0..<5 {
            for j in 0..<5 {
                #expect(m[i, j] == 0.0)
            }
        }
    }

    @Test func diagonalAlwaysZeroAfterWrite() async throws {
        var m = GeneticDistanceMatrix(count: 3)
        m[0, 1] = 5.0
        m[0, 2] = 3.0
        for i in 0..<3 {
            #expect(m[i, i] == 0.0)
        }
    }

    @Test func subscriptIsSymmetric() async throws {
        var m = GeneticDistanceMatrix(count: 4)
        m[0, 3] = 7.5
        m[1, 2] = 2.0
        #expect(m[3, 0] == 7.5)
        #expect(m[2, 1] == 2.0)
    }

    @Test func addAccumulatesDistances() async throws {
        var a = GeneticDistanceMatrix(count: 3)
        a[0, 1] = 1.0; a[0, 2] = 4.0; a[1, 2] = 1.0
        var b = GeneticDistanceMatrix(count: 3)
        b[0, 1] = 3.0; b[0, 2] = 1.0; b[1, 2] = 1.0
        a.add(b)
        #expect(a[0, 1] == 4.0)
        #expect(a[0, 2] == 5.0)
        #expect(a[1, 2] == 2.0)
    }

    @Test func subtractUndoesAdd() async throws {
        var total = GeneticDistanceMatrix(count: 3)
        total[0, 1] = 4.0; total[0, 2] = 5.0; total[1, 2] = 2.0
        var locus = GeneticDistanceMatrix(count: 3)
        locus[0, 1] = 1.0; locus[0, 2] = 4.0; locus[1, 2] = 1.0
        total.subtract(locus)
        #expect(total[0, 1] == 3.0)
        #expect(total[0, 2] == 1.0)
        #expect(total[1, 2] == 1.0)
    }

    @Test func denseIsSymmetricWithZeroDiagonal() async throws {
        var m = GeneticDistanceMatrix(count: 3)
        m[0, 1] = 2.0; m[0, 2] = 5.0; m[1, 2] = 3.0
        let d = m.dense()
        #expect(d.count == 3)
        #expect(d[0][1] == 2.0 && d[1][0] == 2.0)
        #expect(d[0][2] == 5.0 && d[2][0] == 5.0)
        #expect(d[1][2] == 3.0 && d[2][1] == 3.0)
        for i in 0..<3 { #expect(d[i][i] == 0.0) }
    }

    @Test func equalityReflexive() async throws {
        var m = GeneticDistanceMatrix(count: 3)
        m[0, 1] = 2.0
        #expect(m == m)
    }

    // MARK: - smousePeakallDistance(column:)

    // AA(code 1), AB(code 2), BB(code 3), missing(code 0)
    // Expected: d(0,1)=1, d(0,2)=4, d(1,2)=1; pairs involving missing → 0 (skipped).
    @Test func singleBiallelicColumnDistances() async throws {
        let book = AlleleCodebook(alleles: ["G", "A"])
        let column = BiallelicColumn(codebook: book, codes: [1, 2, 3, 0])
        let dm = smousePeakallDistance(column: column)
        #expect(dm.count == 4)
        #expect(dm[0, 1] == 1.0)
        #expect(dm[0, 2] == 4.0)
        #expect(dm[0, 3] == 0.0)   // missing — left as zero
        #expect(dm[1, 2] == 1.0)
        #expect(dm[1, 3] == 0.0)
        #expect(dm[2, 3] == 0.0)
    }

    // MARK: - GenotypeMatrix extensions

    // 4 individuals, 2 loci (SNP + microsatellite), matching GenotypeMatrixTests fixture.
    //   SNP codes:   i0=AA(1), i1=AB(2), i2=BB(3), i3=missing(0)
    //   msat alleles: i0=(1,1), i1=(2,3), i2=(1,2), i3=missing
    //
    // SNP distances:  d(0,1)=1, d(0,2)=4, d(1,2)=1
    // msat distances: d(0,1)=3, d(0,2)=1, d(1,2)=1
    // total:          d(0,1)=4, d(0,2)=5, d(1,2)=2
    private func makeMatrix() -> GenotypeMatrix {
        let individuals = [
            Individual(name: "i0"), Individual(name: "i1"),
            Individual(name: "i2"), Individual(name: "i3"),
        ]
        let snpBook = AlleleCodebook(alleles: ["G", "A"])
        let snp = BiallelicColumn(codebook: snpBook, codes: [1, 2, 3, 0])
        let msatBook = AlleleCodebook(alleles: ["142", "146", "150"])
        let msat = MultiallelicColumn(
            codebook: msatBook,
            left:  [1, 2, 1, 0],
            right: [1, 3, 2, 0]
        )
        return GenotypeMatrix(
            individuals: individuals,
            loci: [Locus(name: "snp1", location: 100, contig: "1"),
                   Locus(name: "mp20", location: 0,   contig: "0")],
            columns: [snp, msat]
        )
    }

    @Test func locusDistanceMatchesSingleColumnResult() async throws {
        let m = makeMatrix()
        let dm = m.locusDistance(atLocus: 0)
        #expect(dm[0, 1] == 1.0)
        #expect(dm[0, 2] == 4.0)
        #expect(dm[1, 2] == 1.0)
    }

    @Test func totalGeneticDistanceAccumulatesLoci() async throws {
        let m = makeMatrix()
        let dm = m.geneticDistance()
        #expect(dm[0, 1] == 4.0)
        #expect(dm[0, 2] == 5.0)
        #expect(dm[1, 2] == 2.0)
    }

    @Test func geneticDistanceOverLocusSubsetSumsToTotal() async throws {
        let m = makeMatrix()
        let snpOnly  = m.geneticDistance(overLoci: [0])
        let msatOnly = m.geneticDistance(overLoci: [1])
        let both     = m.geneticDistance(overLoci: 0..<2)
        for (i, j) in [(0,1),(0,2),(1,2)] {
            #expect(snpOnly[i,j] + msatOnly[i,j] == both[i,j])
        }
    }

    // MARK: - AMOVA bridge

    @Test func amovaInitFromDistanceMatchesDirectInit() async throws {
        var dm = GeneticDistanceMatrix(count: 4)
        dm[0, 1] = 2.0; dm[0, 2] = 8.0; dm[0, 3] = 8.0
        dm[1, 2] = 8.0; dm[1, 3] = 8.0; dm[2, 3] = 2.0
        let fromDM  = AMOVA(distance: dm)
        let fromRaw = AMOVA(squaredDistances: dm.dense())
        #expect(abs(fromDM.totalSS - fromRaw.totalSS) < 1e-12)
    }

    @Test func amovaFromGeneticDistanceDecomposesValidly() async throws {
        let m = makeMatrix()
        let dm = m.geneticDistance()
        let result = AMOVA(distance: dm).decompose(partition: [0, 0, 1, 1])
        // Phi can be negative when within-group variance exceeds between-group variance;
        // only guarantee the SS identity and that phi is a finite number.
        #expect(result.phi.isFinite)
        #expect(abs(result.withinSS + result.amongSS - result.totalSS) < 1e-10)
    }

    // MARK: - MissingDataStrategy
    //
    // `makeMatrix()`'s only individual with missing data (i3) is missing at
    // EVERY locus, so none of the assertions above actually exercise partial
    // coverage — a pair is either fully scored or never scored, and the three
    // strategies agree in both cases. This fixture instead has i2 missing at
    // exactly one of three loci, so perLocusMean/rescaleToTotalLoci/impute
    // genuinely diverge and can be checked by hand.
    //
    //   L1: i0=AA(1) i1=AB(2) i2=BB(3)       — d(0,1)=1 d(0,2)=4 d(1,2)=1
    //   L2: i0=AA(1) i1=AB(2) i2=missing(0)  — d(0,1)=1 d(0,2)=excluded d(1,2)=excluded
    //   L3: i0=AA(1) i1=AB(2) i2=BB(3)       — d(0,1)=1 d(0,2)=4 d(1,2)=1
    //
    // Pair (0,1): scored at all 3 loci — every strategy agrees (raw sum 3).
    // Pair (0,2): scored at 2 of 3 loci — raw/covered sum 8.
    // Pair (1,2): scored at 2 of 3 loci — raw/covered sum 2.
    private func makePartiallyMissingMatrix() -> GenotypeMatrix {
        let individuals = [Individual(name: "i0"), Individual(name: "i1"), Individual(name: "i2")]
        let book = AlleleCodebook(alleles: ["G", "A"])
        let l1 = BiallelicColumn(codebook: book, codes: [1, 2, 3])
        let l2 = BiallelicColumn(codebook: book, codes: [1, 2, 0])
        let l3 = BiallelicColumn(codebook: book, codes: [1, 2, 3])
        return GenotypeMatrix(
            individuals: individuals,
            loci: [Locus(name: "L1"), Locus(name: "L2"), Locus(name: "L3")],
            columns: [l1, l2, l3]
        )
    }

    @Test func perLocusMeanAveragesOverOnlyTheLociActuallyScored() async throws {
        let dm = makePartiallyMissingMatrix().geneticDistance(strategy: .perLocusMean)
        #expect(dm[0, 1] == 1.0)  // 3 loci scored: 3/3
        #expect(dm[0, 2] == 4.0)  // 2 loci scored: 8/2
        #expect(dm[1, 2] == 1.0)  // 2 loci scored: 2/2
    }

    @Test func rescaleToTotalLociProjectsOntoTheFullPanelScale() async throws {
        let dm = makePartiallyMissingMatrix().geneticDistance(strategy: .rescaleToTotalLoci)
        #expect(dm[0, 1] == 3.0)   // fully scored: (3/3)*3 == raw sum, unchanged
        #expect(dm[0, 2] == 12.0) // (8/2)*3 — NOT the raw sum of 8; that undercounted a missing locus
        #expect(dm[1, 2] == 3.0)  // (2/2)*3
    }

    @Test func rescaleToTotalLociIsTheDefaultAndMatchesRawSumWhenFullyScored() async throws {
        let m = makePartiallyMissingMatrix()
        let defaulted = m.geneticDistance()
        let explicit = m.geneticDistance(strategy: .rescaleToTotalLoci)
        #expect(defaulted[0, 1] == explicit[0, 1])
        #expect(defaulted[0, 2] == explicit[0, 2])
        #expect(defaulted[1, 2] == explicit[1, 2])
    }

    @Test func imputeFillsTheMissingLocusFromObservedAlleleFrequencies() async throws {
        // At L2, only i0 (AA) and i1 (AB) are real: allele "G" count 3, "A"
        // count 1 (N=4) — frequencies 0.75/0.25, so i2's imputed dosage is
        // (1.5, 0.5). Hand-computed d²(i0,i2)_L2 = d²(i1,i2)_L2 = 0.25.
        let dm = makePartiallyMissingMatrix().geneticDistance(strategy: .impute)
        #expect(dm[0, 1] == 3.0)   // unaffected — no missing data involved
        #expect(dm[0, 2] == 8.25)  // 4 (L1) + 0.25 (L2, imputed) + 4 (L3)
        #expect(dm[1, 2] == 2.25)  // 1 (L1) + 0.25 (L2, imputed) + 1 (L3)
    }

    @Test func neverJointlyScoredPairStaysZeroRatherThanNaN() async throws {
        // Reuses makeMatrix(), where i3 is missing at every locus — covered
        // count is 0 for every pair involving i3, which must not divide by zero.
        let m = makeMatrix()
        for strategy: MissingDataStrategy in [.perLocusMean, .rescaleToTotalLoci] {
            let dm = m.geneticDistance(strategy: strategy)
            #expect(dm[0, 3] == 0.0)
            #expect(dm[1, 3] == 0.0)
            #expect(dm[2, 3] == 0.0)
        }
    }
}
