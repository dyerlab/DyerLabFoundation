//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PhylogAnalysisIntegrationTests.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//
//  End-to-end validation of the analysis pipeline (geneticDistance, AMOVA,
//  rarefaction) against the real phylog SNP dataset (1318 individuals x 926
//  loci) — everything elsewhere has only been proven against small hand-built
//  fixtures. Individual names encode their sampling site as a trailing state
//  abbreviation (e.g. "AlligatorRiverNC", "AkronZooOH"), which gives real
//  population structure to partition on.

import Testing
import Foundation
import Matrix
@testable import PopulationGenetics

struct PhylogAnalysisIntegrationTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func loadDataFile(_ name: String) throws -> String {
        try String(contentsOf: Self.repoRoot.appendingPathComponent("Data").appendingPathComponent(name), encoding: .utf8)
    }

    private func importPhylog() throws -> GenotypeMatrix {
        try importVCFTools012(
            dosageText: try loadDataFile("phylog.012"),
            indvText: try loadDataFile("phylog.012.indv"),
            posText: try loadDataFile("phylog.012.pos")
        ).matrix
    }

    /// Trailing capital-letter state code, e.g. "AlligatorRiverNC_1272" -> "NC".
    /// Individual names carry a trailing `_<digits>` sample id, so that must be
    /// stripped before the uppercase-run scan — scanning straight from the end
    /// hits a digit immediately and yields "" for every name.
    private func stateCode(for name: String) -> String {
        let withoutTrailingID = String(name.reversed().drop(while: { $0.isNumber || $0 == "_" }).reversed())
        return String(withoutTrailingID.reversed().prefix(while: { $0.isUppercase }).reversed())
    }

    @Test func geneticDistanceComputesOverFullRealPanel() async throws {
        let matrix = try importPhylog()
        #expect(matrix.individualCount == 1318)
        #expect(matrix.locusCount == 926)

        let clock = ContinuousClock()
        let start = clock.now
        let distance = matrix.geneticDistance(strategy: .rescaleToTotalLoci)
        let elapsed = clock.now - start
        print("geneticDistance over \(matrix.individualCount) individuals x \(matrix.locusCount) loci took \(elapsed)")

        // Every pair should have a finite, non-negative squared distance —
        // real SNP-scale data with ~11% missingness is exactly what would
        // surface a NaN/negative-count bug in the coverage-normalization path.
        for i in 0..<10 {
            for j in (i + 1)..<10 {
                #expect(distance[i, j].isFinite)
                #expect(distance[i, j] >= 0.0)
            }
        }
    }

    @Test func amovaDecomposesRealPanelByStateOfOrigin() async throws {
        let matrix = try importPhylog()

        var stateIndex: [String: Int] = [:]
        var partition: [Int] = []
        for individual in matrix.individuals {
            let code = stateCode(for: individual.name)
            let idx = stateIndex[code] ?? stateIndex.count
            stateIndex[code] = idx
            partition.append(idx)
        }
        // Real data: many distinct sampling states, not a degenerate single group.
        #expect(stateIndex.count > 5)
        #expect(partition.count == matrix.individualCount)

        let distance = matrix.geneticDistance(strategy: .rescaleToTotalLoci)
        let amova = AMOVA(distance: distance)
        let result = amova.decompose(partition: partition)

        #expect(result.phi.isFinite)
        #expect(abs((result.withinSS + result.amongSS) - result.totalSS) < 1e-6)
        #expect(result.groupCount == stateIndex.count)

        // A handful of permutations (not the default 999) — enough to prove
        // the permutation path runs correctly on real data without making
        // this test slow; `decompose`'s own O(n^2) summation repeats per
        // iteration but doesn't re-touch genotypes, so this is far cheaper
        // than the geneticDistance() call above.
        let permutation = amova.permutationTest(partition: partition, iterations: 10, seed: 42, tag: .amovaPhiST)
        #expect(permutation.values.count == 10)
        #expect(permutation.analysisType == .amovaPhiST)
        let p = permutation.pValue()
        #expect(p > 0.0 && p <= 1.0)
    }

    @Test func rarefactionRunsOnRealSiteWithSufficientSampleSize() async throws {
        let matrix = try importPhylog()

        // Pick a real site with enough individuals to rarefy meaningfully.
        // Individual names are unique (no grouping by name alone), so group
        // by the human-readable site prefix instead (name minus its trailing
        // digits/underscore, e.g. "AlligatorRiverNC_1102" -> "AlligatorRiverNC").
        var byPrefix: [String: [Int]] = [:]
        for (ordinal, individual) in matrix.individuals.enumerated() {
            let prefix = String(individual.name.reversed().drop(while: { $0.isNumber || $0 == "_" }).reversed())
            byPrefix[prefix, default: []].append(ordinal)
        }
        guard let (_, ordinals) = byPrefix.max(by: { $0.value.count < $1.value.count }), ordinals.count >= 20 else {
            Issue.record("expected at least one real site with >= 20 individuals")
            return
        }

        // Real biallelic SNP data — genotypic (.Ho) rarefaction via
        // individual-based resampling across this site's individuals, at a
        // single real locus, at half the site's sample size.
        let locus = matrix.columns[0]
        let genotypes = ordinals.compactMap { individualOrdinal -> Genotype? in
            guard let (a, b) = locus.alleles(at: individualOrdinal) else { return nil }
            return Genotype(leftAllele: String(a), rightAllele: String(b))
        }
        #expect(!genotypes.isEmpty)
        try #require(genotypes.count >= 4, "site should have enough real (non-missing) calls at this locus to rarefy")

        let result = genotypicRarefaction(genotypes: genotypes, type: .Ho, size: genotypes.count / 2, iterations: 50, seed: 42)
        let unwrapped = try #require(result)
        #expect(unwrapped.values.count == 50)
        #expect(unwrapped.observed >= 0.0 && unwrapped.observed <= 1.0)
        #expect(unwrapped.values.allSatisfy { $0 >= 0.0 && $0 <= 1.0 })
    }

    @Test func pairwisePhiSTOnRealPanelProducesSymmetricFiniteMatrix() async throws {
        let matrix = try importPhylog()

        var stateIndex: [String: Int] = [:]
        var strata: [String] = []
        for individual in matrix.individuals {
            let code = stateCode(for: individual.name)
            stateIndex[code, default: 0] += 1
            strata.append(code)
        }
        #expect(stateIndex.count > 5)

        // A 50-locus subset keeps this fast — pairwisePhiST's own cost is
        // gather-only (no genotype recomputation), so what's actually being
        // timed here is `.impute` distance construction, not the pairwise step.
        let distance = matrix.geneticDistance(overLoci: 0..<50, strategy: .impute)
        let result = pairwisePhiST(distance: distance, strata: strata)

        #expect(result.groupNames.count == stateIndex.count)
        #expect(result.groupNames == stateIndex.keys.sorted { $0.naturalCompare($1) == .orderedAscending })
        for i in 0..<result.groupNames.count {
            #expect(result[i, i] == 0.0)
            for j in (i + 1)..<result.groupNames.count {
                #expect(result[i, j].isFinite)
                #expect(result[i, j] == result[j, i])
            }
        }
    }
}
