//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RarefactionTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2025.06.05.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import PopulationGenetics

@MainActor
struct RarefactionTests {

    @Test func allelicRarefactionOfClusterStrata() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        let sbp = dataStore.getStratum(named: "SBP-C", within: "Cluster")
        let nbp = dataStore.getStratum(named: "NBP-C", within: "Cluster")

        #expect(sbp != nil)
        #expect(nbp != nil)

        #expect(dataStore.getIndividuals(for: sbp!).count == 18)
        #expect(dataStore.getIndividuals(for: nbp!).count == 84)

        let genotypes = dataStore.getGenotypes(for: nbp!, locusName: "MP20")
        #expect(genotypes.count == 84)

        let sameSizeRarefaction = AllelicRarefaction(genotypes: genotypes,
                                                      type: .A,
                                                      size: 84, iterations: 10, seed: 42)

        #expect(sameSizeRarefaction.observed == 6.0)
        #expect(sameSizeRarefaction.analysisType == .rarefaction(.A))
        #expect(sameSizeRarefaction.values.count == 10)
        #expect(sameSizeRarefaction.values == Array(repeating: 6.0, count: 10))

        let aeRarefaction = AllelicRarefaction(genotypes: genotypes,
                                               type: .Ae,
                                               size: 84, iterations: 10, seed: 42)
        #expect((aeRarefaction.observed - aeRarefaction.values.first!) < 0.000001)

    }

    // MARK: - Missing-data regression tests
    //
    // `leftAllele`/`rightAllele` are non-optional `String`, so the allele pool
    // used to be built with `compactMap`, which is a silent no-op on a
    // non-optional return — every empty-string missing/haploid placeholder
    // leaked into the resampling pool as a literal "" allele. These tests lock
    // in the fix: empty placeholders must never appear as a resampled allele.

    @Test func allelicRarefactionExcludesMissingAllelesFromPool() async throws {
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
        let result = AllelicRarefaction(genotypes: genotypes, type: .A, size: 3, iterations: 20, seed: 42)

        #expect(result.values.count == 20)
        #expect(result.values.allSatisfy { $0 == 1.0 })
    }

    @Test func allelicRarefactionGuardsAgainstInsufficientRealAlleles() async throws {
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
        let result = AllelicRarefaction(genotypes: genotypes, type: .A, size: 5, iterations: 5, seed: 42)

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

    @Test func genotypicRarefactionHoOnUniformHeterozygotes() async throws {
        // Every genotype is heterozygous, so Ho == 1.0 for the full sample
        // AND for any subsample — deterministic regardless of which
        // individuals get shuffled out.
        let genotypes = (0..<5).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }
        let result = GenotypicRarefaction(genotypes: genotypes, type: .Ho, size: 4, iterations: 15, seed: 42)

        let unwrapped = try #require(result)
        #expect(unwrapped.analysisType == .rarefaction(.Ho))
        #expect(unwrapped.observed == 1.0)
        #expect(unwrapped.values.count == 15)
        #expect(unwrapped.values.allSatisfy { $0 == 1.0 })
    }

    @Test func genotypicRarefactionHeOnUniformHomozygotes() async throws {
        // A monomorphic population (every genotype "A:A") has He == 0.0 for
        // the full sample and any subsample — deterministic for the same
        // reason as above.
        let genotypes = (0..<5).map { _ in Genotype(leftAllele: "A", rightAllele: "A") }
        let result = GenotypicRarefaction(genotypes: genotypes, type: .He, size: 4, iterations: 15, seed: 42)

        let unwrapped = try #require(result)
        #expect(unwrapped.analysisType == .rarefaction(.He))
        #expect(unwrapped.observed == 0.0)
        #expect(unwrapped.values.count == 15)
        #expect(unwrapped.values.allSatisfy { $0 == 0.0 })
    }

    @Test func genotypicRarefactionRejectsHierarchicalTypes() async throws {
        let genotypes = (0..<20).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }
        for type: DiversityType in [.Ht, .Hi, .Hos, .Hes, .Pe] {
            #expect(GenotypicRarefaction(genotypes: genotypes, type: type, size: 10, iterations: 5, seed: 42) == nil,
                    "\(type) requires population structure this flat genotype list can't provide")
        }
    }

    @Test func genotypicRarefactionRejectsUndefined() async throws {
        let genotypes = (0..<20).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }
        #expect(GenotypicRarefaction(genotypes: genotypes, type: .Undefined, size: 10, iterations: 5, seed: 42) == nil)
    }

    @Test func genotypicRarefactionA95OnUniformHeterozygotes() async throws {
        // Every genotype is "A:B" (freq(A) == freq(B) == 0.5, both >= 5%), so
        // A95 == 2.0 for the full sample and any subsample — deterministic.
        let genotypes = (0..<6).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }
        let result = try #require(GenotypicRarefaction(genotypes: genotypes,
                                                       type: .A95,
                                                       size: 4,
                                                       iterations: 10,
                                                       seed: 42))
        #expect(result.observed == 2.0)
        #expect(result.values.allSatisfy { $0 == 2.0 })
    }

    @Test func genotypicRarefactionAllelicMetricsOnUniformHeterozygotes() async throws {
        // Every genotype is "A:B", so any subsample has freq(A) == freq(B)
        // == 0.5 regardless of which individuals get shuffled out —
        // richness (.A) and effective-alleles (.Ae) are both deterministic.
        let genotypes = (0..<6).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }

        let richness = try #require(GenotypicRarefaction(genotypes: genotypes,
                                                         type: .A,
                                                         size: 4,
                                                         iterations: 10,
                                                         seed: 42))
        #expect(richness.observed == 2.0)
        #expect(richness.values.count == 10)
        #expect(richness.values.allSatisfy { $0 == 2.0 })

        let effective = try #require(GenotypicRarefaction(genotypes: genotypes,
                                                          type: .Ae,
                                                          size: 4,
                                                          iterations: 10,
                                                          seed: 42))
        #expect(effective.observed == 2.0)
        #expect(effective.values.allSatisfy { $0 == 2.0 })
    }

    @Test func allelicAndGenotypicRarefactionAgreeOnObservedForCompleteData() async throws {
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

        let byAllele = AllelicRarefaction(genotypes: genotypes, type: .A, size: 10, iterations: 5, seed: 42)
        let byIndividual = try #require(GenotypicRarefaction(genotypes: genotypes,
                                                             type: .A,
                                                             size: 10,
                                                             iterations: 5,
                                                             seed: 42))
        #expect(byAllele.observed == byIndividual.observed)
    }

    @Test func genotypicRarefactionGuardsInvalidDirectCallParameters() async throws {
        let genotypes = (0..<5).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }
        #expect(GenotypicRarefaction(genotypes: [], type: .Ho, size: 5, seed: 42) == nil)
        #expect(GenotypicRarefaction(genotypes: genotypes, type: .Ho, size: 0, seed: 42) == nil)
        #expect(GenotypicRarefaction(genotypes: genotypes, type: .Ho, size: 5, seed: 42) == nil)  // must be < count
        #expect(GenotypicRarefaction(genotypes: genotypes, type: .Ho, size: 6, seed: 42) == nil)
    }

    // MARK: - Rarefaction() top-level dispatcher
    //
    // Previously entirely untested — every guard and both dispatch branches.

    @Test func rarefactionDispatchesToAllelicForAllelicTypes() async throws {
        let genotypes = (0..<20).map { i in Genotype(leftAllele: i.isMultiple(of: 2) ? "A" : "B", rightAllele: "A") }
        let result = Rarefaction(genotypes: genotypes, type: .A, size: 10, iterations: 5, seed: 42)
        #expect(result?.analysisType == .rarefaction(.A))
    }

    @Test func rarefactionDispatchesToGenotypicForSupportedGenotypicTypes() async throws {
        let genotypes = (0..<20).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }
        let result = Rarefaction(genotypes: genotypes, type: .Ho, size: 10, iterations: 5, seed: 42)
        #expect(result?.analysisType == .rarefaction(.Ho))
        #expect(result?.observed == 1.0)
    }

    @Test func rarefactionReturnsNilForUnsupportedHierarchicalGenotypicTypes() async throws {
        let genotypes = (0..<20).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }
        #expect(Rarefaction(genotypes: genotypes, type: .Ht, size: 10, iterations: 5, seed: 42) == nil)
    }

    @Test func rarefactionReturnsNilForUndefinedType() async throws {
        let genotypes = (0..<20).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }
        #expect(Rarefaction(genotypes: genotypes, type: .Undefined, size: 10, iterations: 5, seed: 42) == nil)
    }

    @Test func rarefactionValidatesParameters() async throws {
        let genotypes = (0..<20).map { _ in Genotype(leftAllele: "A", rightAllele: "B") }
        #expect(Rarefaction(genotypes: [], type: .A, size: 10, seed: 42) == nil)                      // empty
        #expect(Rarefaction(genotypes: genotypes, type: .A, size: 20, seed: 42) == nil)               // size >= count
        #expect(Rarefaction(genotypes: genotypes, type: .A, size: 10, iterations: 1, seed: 42) == nil) // iterations < 2
        #expect(Rarefaction(genotypes: genotypes, type: .A, size: 5, seed: 42) == nil)                // size < 10
    }

}
