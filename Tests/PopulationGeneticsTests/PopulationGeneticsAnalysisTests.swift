//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopulationGeneticsAnalysisTests.swift
//  PopulationGeneticsTests
//
//  Checks that each `Analysis` conformer gives the same answer as the
//  function it fronts; the numerical behaviour of those functions is tested
//  in their own suites.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Testing
import Matrix
import PresentationZen
@testable import PopulationGenetics

struct PopulationGeneticsAnalysisTests {

    // MARK: - Fixtures

    /// Four individuals, strata in non-contiguous order: A, B, A, B.
    private func distances() -> GeneticDistanceMatrix {
        var d = GeneticDistanceMatrix(count: 4)
        d[0, 2] = 2; d[1, 3] = 2
        d[0, 1] = 8; d[0, 3] = 8; d[2, 1] = 8; d[2, 3] = 8
        return d
    }

    /// Four maternal families of a 1/1 mother and four offspring; each family
    /// has a single sire, carrying a different allele per family.
    private func families() -> (GenotypeMatrix, ParentageDesign) {
        var codebook = AlleleCodebook()
        for allele in ["A", "B", "C", "D"] { codebook.register(allele) }
        var individuals: [Individual] = []
        var left: [UInt8] = []
        var right: [UInt8] = []
        var families: [MaternalFamily] = []
        for family in 0..<4 {
            individuals.append(Individual(name: "Mom\(family)"))
            let mother = individuals.count - 1
            left.append(1); right.append(1)
            var offspring: [Int] = []
            for n in 0..<4 {
                individuals.append(Individual(name: "Off\(family)_\(n)"))
                offspring.append(individuals.count - 1)
                left.append(1); right.append(UInt8(family + 1))
            }
            families.append(MaternalFamily(id: "F\(family)", mother: mother, offspring: offspring))
        }
        let column = MultiallelicColumn(codebook: codebook, left: left, right: right)
        let matrix = GenotypeMatrix(individuals: individuals, loci: [Locus(name: "L1")], columns: [column])
        return (matrix, ParentageDesign(families: families))
    }

    private func genotypes() -> [Genotype] {
        (0..<20).map { Genotype(leftAllele: $0.isMultiple(of: 2) ? "A" : "B", rightAllele: $0 < 5 ? "C" : "A") }
    }

    // MARK: - AMOVA

    @Test func strataBuildTheSamePartitionAsAMOVA() throws {
        let analysis = try #require(AMOVAAnalysis(distance: distances(), strata: ["A", "B", "A", "B"]))
        #expect(analysis.partition == [0, 1, 0, 1])
        #expect(analysis.tag == .amovaPhiST)

        let outcome = try #require(analysis.run(options: AnalysisOptions(iterations: 0)))
        let direct = AMOVA(distance: distances()).decompose(partition: [0, 1, 0, 1])
        #expect(abs(outcome.phi - direct.phi) < 1e-12)
        #expect(abs(outcome.phi - 0.75) < 1e-12)
    }

    @Test func customTagsReachTheNullDistribution() throws {
        let analysis = try #require(AMOVAAnalysis(distance: distances(), strata: ["A", "B", "A", "B"],
                                                  tag: .twoGenerPhiFT))
        let outcome = try #require(analysis.run(options: AnalysisOptions(iterations: 19, seed: 7)))
        #expect(outcome.tag == .twoGenerPhiFT)
        #expect(outcome.statisticLabel == "Φ_ST")
        #expect(outcome.distribution?.analysisType == .twoGenerPhiFT)
    }

    @Test func mismatchedStrataGiveNil() {
        #expect(AMOVAAnalysis(distance: distances(), strata: ["A", "B"]) == nil)
    }

    // MARK: - Rarefaction

    @Test func rarefactionMatchesTheFunction() throws {
        let analysis = try #require(DiversityRarefactionAnalysis(genotypes: genotypes(), type: .A, size: 10))
        let outcome = try #require(analysis.run(options: AnalysisOptions(iterations: 50, seed: 3)))
        let direct = try #require(Rarefaction(genotypes: genotypes(), type: .A, size: 10, iterations: 50, seed: 3))

        #expect(outcome.analysisType == .rarefaction)
        #expect(outcome.tag == .rarefaction(.A))
        #expect(outcome.distribution == direct)
        #expect(outcome.fullSampleValue == direct.observed)
        #expect(abs(outcome.statistic - direct.values.reduce(0, +) / 50) < 1e-12)
        #expect(outcome.pValue == nil)
        let interval = try #require(outcome.interval)
        // A mean and a quantile interval are different summaries; the mean need not fall inside it.
        #expect(interval == empiricalQuantile(direct.values, probability: 0.025)
                ... empiricalQuantile(direct.values, probability: 0.975))
    }

    @Test func individualBasedRarefactionUsesGenotypicResampling() throws {
        let analysis = try #require(DiversityRarefactionAnalysis(genotypes: genotypes(), type: .A, size: 10,
                                                        individualBased: true))
        let outcome = try #require(analysis.run(options: AnalysisOptions(iterations: 50, seed: 3)))
        let direct = GenotypicRarefaction(genotypes: genotypes(), type: .A, size: 10, iterations: 50, seed: 3)
        #expect(outcome.distribution == direct)
    }

    @Test func unusableRarefactionGivesNil() throws {
        #expect(DiversityRarefactionAnalysis(genotypes: genotypes(), type: .Undefined, size: 10) == nil)
        #expect(DiversityRarefactionAnalysis(genotypes: genotypes(), type: .A, size: 20) == nil)
        let analysis = try #require(DiversityRarefactionAnalysis(genotypes: genotypes(), type: .A, size: 10))
        #expect(analysis.run(options: AnalysisOptions(iterations: 1)) == nil)
    }

    // MARK: - Outcrossing

    @Test func outcrossingUsesTheOptionsSeed() throws {
        let (matrix, design) = families()
        var parameters = Outcrossing.Parameters()
        parameters.numSteps = 2000
        parameters.burnIn = 500
        parameters.thinning = 5
        parameters.seed = 999 // replaced by the options' seed

        let analysis = try #require(OutcrossingAnalysis(matrix: matrix, design: design, parameters: parameters))
        let outcome = try #require(analysis.run(options: AnalysisOptions(seed: 42)))

        parameters.seed = 42
        let direct = matrix.runOutcrossing(design: design, parameters: parameters)
        #expect(outcome.statistic == direct.meanT)
        #expect(outcome.analysisType == .outcrossing)
        #expect(outcome.pValue == nil)
        let (lower, upper) = direct.credibleIntervalT(percentile: 0.95)
        #expect(outcome.interval == lower...upper)
    }

    @Test func unusableOutcrossingGivesNil() {
        let (matrix, design) = families()
        #expect(OutcrossingAnalysis(matrix: matrix, design: ParentageDesign(families: [])) == nil)
        #expect(OutcrossingAnalysis(matrix: matrix, design: design, hasNullModel: [true, false]) == nil)
        #expect(OutcrossingAnalysis(matrix: matrix, design: design, locus: 1) == nil)
    }

    // MARK: - Correlated paternity

    @Test func correlatedPaternityMatchesTheMethod() throws {
        let (matrix, design) = families()
        let analysis = try #require(CorrelatedPaternityAnalysis(matrix: matrix, design: design))
        let outcome = try #require(analysis.run(options: AnalysisOptions()))
        #expect(outcome.statistic == matrix.correlatedPaternity(design: design).rp)
        #expect(outcome.analysisType == .correlatedPaternity)
        #expect(outcome.distribution == nil)
        #expect(outcome.pValue == nil)
    }

    // MARK: - Protocol

    @Test func everyOutcomeReportsItsOwnType() throws {
        let (matrix, design) = families()
        let analyses: [any Analysis] = [
            try #require(AMOVAAnalysis(distance: distances(), strata: ["A", "B", "A", "B"])),
            try #require(DiversityRarefactionAnalysis(genotypes: genotypes(), type: .Ho, size: 10)),
            try #require(CorrelatedPaternityAnalysis(matrix: matrix, design: design)),
        ]
        for analysis in analyses {
            let outcome = try #require(analysis.run(options: AnalysisOptions(iterations: 19, seed: 1)))
            #expect(outcome.analysisType == analysis.analysisType)
        }
    }

    // MARK: - Reports

    @Test func everyReportIsFilled() throws {
        let (matrix, design) = families()
        var parameters = Outcrossing.Parameters()
        parameters.numSteps = 2000
        parameters.burnIn = 500
        parameters.thinning = 5
        let options = AnalysisOptions(iterations: 19, seed: 1)
        let reports: [AnalysisReport] = [
            try #require(AMOVAAnalysis(distance: distances(), strata: ["A", "B", "A", "B"])?.perform(options: options)).report,
            try #require(DiversityRarefactionAnalysis(genotypes: genotypes(), type: .Ho, size: 10)?.perform(options: options)).report,
            try #require(DiversityRarefactionAnalysis(genotypes: genotypes(), type: .A, size: 10)?.perform(options: options)).report,
            try #require(CorrelatedPaternityAnalysis(matrix: matrix, design: design)?.perform(options: options)).report,
            try #require(OutcrossingAnalysis(matrix: matrix, design: design, parameters: parameters)?.perform(options: options)).report,
        ]
        for report in reports {
            #expect(!(report.methods + report.results).contains("{"), "\(report.methods) \(report.results)")
            #expect(!report.methods.isEmpty && !report.results.isEmpty)
        }
        #expect(reports[0].methods.contains("4 individuals") && reports[0].results.contains("Φ_ST = 0.750"))
        #expect(reports[1].methods.contains("observed heterozygosity (Ho)")
                && reports[1].methods.contains("drawing whole individuals"))
        #expect(reports[2].methods.contains("from the pooled alleles"))
        #expect(reports[4].methods.contains("2,000 steps, the first 500 discarded"))
    }

    @Test func reportsBecomeLogEntriesInManuscriptOrder() throws {
        let (matrix, design) = families()
        let run = try #require(CorrelatedPaternityAnalysis(matrix: matrix, design: design)?.perform())
        let entries = run.report.logEntries
        #expect(entries.first?.logType == .methods && entries.last?.logType == .results)
        #expect(entries.count == run.report.notes.count + 2)
        #expect(entries.allSatisfy { $0.analysisTag == AnalysisType.correlatedPaternity.tag })
    }
}
