//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2025 RJ Dyer.  All Rights Reserved.
//
//  RarefactionTests.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 6/5/25.
//

import Foundation
import Testing
@testable import PopulationGenetics

struct RarefactionTests {


    @Test func testAllelicRarefaction() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        let sbp = dataStore.getStratum(named: "SBP-C", within: "Cluster")
        let nbp = dataStore.getStratum(named: "NBP-C", within: "Cluster")

        #expect( sbp != nil )
        #expect( nbp != nil )

        #expect( dataStore.getIndividuals(for: sbp!).count == 18 )
        #expect( dataStore.getIndividuals(for: nbp!).count == 84 )

        let genotypes = dataStore.getGenotypes(for: nbp!, locusName: "MP20")
        #expect( genotypes.count == 84 )

        let sameSizeRarefaction = allelicRarefaction( genotypes: genotypes,
                                                      type: .A,
                                                      size: 84, iterations: 10, seed: 42  )
        print(sameSizeRarefaction)

        #expect( sameSizeRarefaction.observed == 6.0 )
        #expect( sameSizeRarefaction.analysisType == .rarefaction(.A) )
        #expect( sameSizeRarefaction.values.count == 10 )
        #expect( sameSizeRarefaction.values == Array( repeating: 6.0, count: 10) )

        let aeRarefaction = allelicRarefaction( genotypes: genotypes,
                                               type: .Ae,
                                               size: 84, iterations: 10, seed: 42  )
        print(aeRarefaction)
        #expect( (aeRarefaction.observed - aeRarefaction.values.first!) < 0.000001 )

    }

    // MARK: - Missing-data regression tests
    //
    // `leftAllele`/`rightAllele` are non-optional `String`, so the allele pool
    // used to be built with `compactMap`, which is a silent no-op on a
    // non-optional return — every empty-string missing/haploid placeholder
    // leaked into the resampling pool as a literal "" allele. These tests lock
    // in the fix: empty placeholders must never appear as a resampled allele.

    @Test func testAllelicRarefactionExcludesMissingAllelesFromPool() async throws {
        // 3 complete "A:A" homozygotes + 2 fully-missing genotypes. The only
        // real allele in the data is "A" — if "" ever leaked into the pool,
        // richness (.A) would read 2 instead of 1.
        let genotypes = [
            Genotype(leftAllele: "A", rightAllele: "A"),
            Genotype(leftAllele: "A", rightAllele: "A"),
            Genotype(leftAllele: "A", rightAllele: "A"),
            Genotype(leftAllele: "", rightAllele: ""),
            Genotype(leftAllele: "", rightAllele: ""),
        ]

        // 6 real alleles total ("A" x6); size 3 draws the entire real pool
        // every iteration, so the result is deterministic.
        let result = allelicRarefaction(genotypes: genotypes, type: .A, size: 3, iterations: 20, seed: 42)

        #expect(result.values.count == 20)
        #expect(result.values.allSatisfy { $0 == 1.0 })
    }

    @Test func testAllelicRarefactionGuardsAgainstInsufficientRealAlleles() async throws {
        let genotypes = [
            Genotype(leftAllele: "A", rightAllele: "A"),
            Genotype(leftAllele: "A", rightAllele: "A"),
            Genotype(leftAllele: "A", rightAllele: "A"),
            Genotype(leftAllele: "A", rightAllele: "A"),
            Genotype(leftAllele: "", rightAllele: ""),
            Genotype(leftAllele: "", rightAllele: ""),
        ]
        // N = 6, so size 5 passes the cheap `size >= N*2` check (5 < 12), but
        // the real allele pool is only 8 ("A" x8) and 2*5 = 10 > 8. Before the
        // fix, the stale `alleles.count == 2*N == 12` assumption would have let
        // this through and sampled from a pool contaminated with "".
        let result = allelicRarefaction(genotypes: genotypes, type: .A, size: 5, iterations: 5, seed: 42)

        #expect(result.values.isEmpty)
        #expect(result.observed.isNaN)
        #expect(result.analysisType == .rarefaction(.A))  // requested type is preserved even on the guard path
    }

    // MARK: - genotypicRarefaction
    //
    // Was previously an unimplemented stub returning an empty-but-non-nil
    // result for every type, silently masquerading as success.
    // `.Ho`/`.He` are now really computed (single-population statistics,
    // resampling whole genotypes rather than decomposed alleles). `.Ht`,
    // `.Hi`, `.Hos`, `.Hes`, `.Pe` are Nei-style hierarchical measures that
    // need explicit population/stratum partitioning this flat `[Genotype]`
    // signature can't express, so they now correctly return `nil`.

    @Test func testGenotypicRarefactionHoOnUniformHeterozygotes() async throws {
        // Every genotype is heterozygous, so Ho == 1.0 for the full sample
        // AND for any subsample — deterministic regardless of which
        // individuals get shuffled out.
        let genotypes = (0..<5).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }
        let result = genotypicRarefaction(genotypes: genotypes, type: .Ho, size: 4, iterations: 15, seed: 42)

        let unwrapped = try #require(result)
        #expect(unwrapped.analysisType == .rarefaction(.Ho))
        #expect(unwrapped.observed == 1.0)
        #expect(unwrapped.values.count == 15)
        #expect(unwrapped.values.allSatisfy { $0 == 1.0 })
    }

    @Test func testGenotypicRarefactionHeOnUniformHomozygotes() async throws {
        // A monomorphic population (every genotype "A:A") has He == 0.0 for
        // the full sample and any subsample — deterministic for the same
        // reason as above.
        let genotypes = (0..<5).map { _ in Genotype(leftAllele: "A", rightAllele: "A") }
        let result = genotypicRarefaction(genotypes: genotypes, type: .He, size: 4, iterations: 15, seed: 42)

        let unwrapped = try #require(result)
        #expect(unwrapped.analysisType == .rarefaction(.He))
        #expect(unwrapped.observed == 0.0)
        #expect(unwrapped.values.count == 15)
        #expect(unwrapped.values.allSatisfy { $0 == 0.0 })
    }

    @Test func testGenotypicRarefactionRejectsHierarchicalTypes() async throws {
        let genotypes = (0..<20).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }
        for type: DiversityType in [.Ht, .Hi, .Hos, .Hes, .Pe] {
            #expect(genotypicRarefaction(genotypes: genotypes, type: type, size: 10, iterations: 5, seed: 42) == nil,
                    "\(type) requires population structure this flat genotype list can't provide")
        }
    }

    @Test func testGenotypicRarefactionRejectsUndefined() async throws {
        let genotypes = (0..<20).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }
        #expect(genotypicRarefaction(genotypes: genotypes, type: .Undefined, size: 10, iterations: 5, seed: 42) == nil)
    }

    @Test func testGenotypicRarefactionA95OnUniformHeterozygotes() async throws {
        // Every genotype is "A:B" (freq(A) == freq(B) == 0.5, both >= 5%), so
        // A95 == 2.0 for the full sample and any subsample — deterministic.
        let genotypes = (0..<6).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }
        let result = try #require(genotypicRarefaction(genotypes: genotypes, type: .A95, size: 4, iterations: 10, seed: 42))
        #expect(result.observed == 2.0)
        #expect(result.values.allSatisfy { $0 == 2.0 })
    }

    @Test func testGenotypicRarefactionAllelicMetricsOnUniformHeterozygotes() async throws {
        // Every genotype is "A:B", so any subsample has freq(A) == freq(B)
        // == 0.5 regardless of which individuals get shuffled out —
        // richness (.A) and effective-alleles (.Ae) are both deterministic.
        let genotypes = (0..<6).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }

        let richness = try #require(genotypicRarefaction(genotypes: genotypes, type: .A, size: 4, iterations: 10, seed: 42))
        #expect(richness.observed == 2.0)
        #expect(richness.values.count == 10)
        #expect(richness.values.allSatisfy { $0 == 2.0 })

        let effective = try #require(genotypicRarefaction(genotypes: genotypes, type: .Ae, size: 4, iterations: 10, seed: 42))
        #expect(effective.observed == 2.0)
        #expect(effective.values.allSatisfy { $0 == 2.0 })
    }

    @Test func testAllelicAndGenotypicRarefactionAgreeOnObservedForCompleteData() async throws {
        // Individual-based and allele-pool resampling are different
        // *resampling* procedures, but the full-sample "observed" statistic
        // itself doesn't depend on resampling method — both should report
        // the same GenotypeFrequencies-derived value.
        let genotypes = [
            Genotype(leftAllele: "A", rightAllele: "A"),
            Genotype(leftAllele: "A", rightAllele: "B"),
            Genotype(leftAllele: "A", rightAllele: "B"),
            Genotype(leftAllele: "B", rightAllele: "B"),
        ] + (0..<16).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }

        let byAllele = allelicRarefaction(genotypes: genotypes, type: .A, size: 10, iterations: 5, seed: 42)
        let byIndividual = try #require(genotypicRarefaction(genotypes: genotypes, type: .A, size: 10, iterations: 5, seed: 42))
        #expect(byAllele.observed == byIndividual.observed)
    }

    @Test func testGenotypicRarefactionGuardsInvalidDirectCallParameters() async throws {
        let genotypes = (0..<5).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }
        #expect(genotypicRarefaction(genotypes: [], type: .Ho, size: 5, seed: 42) == nil)
        #expect(genotypicRarefaction(genotypes: genotypes, type: .Ho, size: 0, seed: 42) == nil)
        #expect(genotypicRarefaction(genotypes: genotypes, type: .Ho, size: 5, seed: 42) == nil)  // must be < count
        #expect(genotypicRarefaction(genotypes: genotypes, type: .Ho, size: 6, seed: 42) == nil)
    }

    // MARK: - rarefaction() top-level dispatcher
    //
    // Previously entirely untested — every guard and both dispatch branches.

    @Test func testRarefactionDispatchesToAllelicForAllelicTypes() async throws {
        let genotypes = (0..<20).map { i in Genotype(leftAllele: i.isMultiple(of: 2) ? "A" : "B", rightAllele: "A") }
        let result = rarefaction(genotypes: genotypes, type: .A, size: 10, iterations: 5, seed: 42)
        #expect(result?.analysisType == .rarefaction(.A))
    }

    @Test func testRarefactionDispatchesToGenotypicForSupportedGenotypicTypes() async throws {
        let genotypes = (0..<20).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }
        let result = rarefaction(genotypes: genotypes, type: .Ho, size: 10, iterations: 5, seed: 42)
        #expect(result?.analysisType == .rarefaction(.Ho))
        #expect(result?.observed == 1.0)
    }

    @Test func testRarefactionReturnsNilForUnsupportedHierarchicalGenotypicTypes() async throws {
        let genotypes = (0..<20).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }
        #expect(rarefaction(genotypes: genotypes, type: .Ht, size: 10, iterations: 5, seed: 42) == nil)
    }

    @Test func testRarefactionReturnsNilForUndefinedType() async throws {
        let genotypes = (0..<20).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }
        #expect(rarefaction(genotypes: genotypes, type: .Undefined, size: 10, iterations: 5, seed: 42) == nil)
    }

    @Test func testRarefactionValidatesParameters() async throws {
        let genotypes = (0..<20).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }
        #expect(rarefaction(genotypes: [], type: .A, size: 10, seed: 42) == nil)                      // empty
        #expect(rarefaction(genotypes: genotypes, type: .A, size: 20, seed: 42) == nil)               // size >= count
        #expect(rarefaction(genotypes: genotypes, type: .A, size: 10, iterations: 1, seed: 42) == nil) // iterations < 2
        #expect(rarefaction(genotypes: genotypes, type: .A, size: 5, seed: 42) == nil)                // size < 10
    }

}
