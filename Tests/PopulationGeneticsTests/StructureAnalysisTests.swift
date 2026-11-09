//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StructureAnalysisTests.swift
//  PopulationGeneticsTests
//
//  Checks that a `StructureAnalysis` gives the same answer as the analysis it
//  fronts, and that its table saves and exports. The statistics themselves
//  are checked against R in `WeirCockerhamTests` and `TwoGenerTests`.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
import Matrix
import PresentationZen
@testable import PopulationGenetics

struct StructureAnalysisTests {

    // MARK: - Options

    @Test func adultOptionsOfferPopulations() throws {
        let dataset = try ExampleDataset.arapatPopulations.load()
        let options = StructureOptions(dataset: dataset, sample: .adults)
        #expect(options.loci.count == dataset.matrix.locusCount)
        let spec = try #require(options.defaultSpec)
        #expect(spec.level == options.levels.last && spec.locus == nil && !spec.isTested)
        #expect(options.validated(StructureSpec(locus: "Nope", level: "Nope")) == spec)
    }

    @Test func gameteOptionsStartWithFamilies() throws {
        let dataset = try ExampleDataset.cornusFamilies.load()
        let options = StructureOptions(dataset: dataset, sample: .paternalGametes)
        #expect(options.levels.first == StructureSpec.familyLevel)
        #expect(options.defaultSpec?.level == StructureSpec.familyLevel)
    }

    @Test func pluralsReadNaturally() {
        #expect(StructureSpec.plural("Population") == "populations")
        #expect(StructureSpec.plural("Family") == "families")
        #expect(StructureSpec.plural("Region") == "regions")
        #expect(StructureSpec.plural("") == "strata")
    }

    // MARK: - Adults

    @Test func multilocusAdultsAreAnAMOVAOfGeneCopies() throws {
        let dataset = try ExampleDataset.arapatPopulations.load()
        let spec = try #require(StructureOptions(dataset: dataset, sample: .adults).defaultSpec)
        #expect(spec.table == .amova && spec.statistic == .phiGeneCopies && spec.statisticLabel == "Φ_ST")
        let result = try #require(StructureAnalysis(spec: spec, dataset: dataset)?.run())
        #expect(result.rows.map(\.source) == [spec.level, "Error", "Total"])
        #expect(result.pValue == nil)
        #expect(result.dataTable.columnNames == ["Source", "df", "SS", "MS", "sigma2", "Phi_ST"])
        #expect(result.report.results.contains("Φ_ST = "))
        #expect(result.report.methods.contains("populations") && result.report.methods.contains("gene copies"))
        #expect(result.legend.contains("ratio of the variance components summed over loci"))
    }

    @Test func completeGenotypesMatchTheDistanceAMOVA() throws {
        // Without missing data, the loci's components summed are the AMOVA of summed distances.
        let dataset = try ExampleDataset.arapatPopulations.load()
        let complete = dataset.adultOrdinals.filter { ordinal in
            dataset.matrix.columns.allSatisfy { column in
                column.alleles(at: ordinal).map { $0.0 != 0 && $0.1 != 0 } ?? false
            }
        }
        let strata = complete.map { dataset.populationName(at: $0) }
        let (loci, incomplete) = StructureLoci.adults(matrix: dataset.matrix, ordinals: complete, strata: strata,
                                                      loci: Array(0..<dataset.matrix.locusCount))
        #expect(incomplete == 0)
        var workspace = loci.makeWorkspace()
        let summed = loci.components(partition: loci.partition, workspace: &workspace).compactMap { $0 }
            .reduce(nil as LocusComponents?) { sum, next in sum.map { $0 + next } ?? next }
        let parts = try #require(summed?.genotypes)
        let direct = try #require(AMOVAAnalysis(distance: dataset.matrix.geneticDistance().submatrix(indices: complete),
                                                strata: strata)?.run(options: AnalysisOptions(iterations: 0)))
        #expect(abs(parts.amongShare - direct.phi) < 1e-10)
        #expect(abs(parts.ss[0] - direct.decomposition.amongSS) < 1e-8 * direct.decomposition.amongSS)
        #expect(parts.df == [direct.decomposition.dfAmong, direct.decomposition.dfWithin])
    }

    @Test func oneAdultLocusOffersEveryStatistic() throws {
        let dataset = try ExampleDataset.arapatPopulations.load()
        let spec = StructureSpec(statistic: .theta, locus: "LTRS", level: "Population", permutations: 99, seed: 3)
        let result = try #require(StructureAnalysis(spec: spec, dataset: dataset)?.run())

        let ordinals = dataset.adultOrdinals
        let direct = try #require(WeirCockerhamAnalysis(column: dataset.matrix.columns[0], locus: "LTRS",
                                                        ordinals: ordinals,
                                                        strata: ordinals.map { dataset.populationName(at: $0) })?
            .run(options: AnalysisOptions(iterations: 0)))
        #expect(spec.statisticLabel == "θ")
        #expect(abs((result.statistic ?? .nan) - direct.decomposition.theta) < 1e-12)
        #expect(result.rows.map(\.source) == ["Population", "Individual", "Error", "Total"])
        #expect(abs((result.rows[3].statistic ?? .nan) - direct.decomposition.fIT) < 1e-12)
        #expect(result.rows[0].df == direct.decomposition.dfAmong)
        #expect(result.dataTable.columnNames == ["Source", "df", "SS", "MS", "sigma2", "F", "P"])
        #expect(result.pValue == 0.01)

        for statistic in [StructureSpec.Statistic.phiGeneCopies, .phiGenotypes] {
            let one = StructureSpec(statistic: statistic, locus: "LTRS", level: "Population")
            let table = try #require(StructureAnalysis(spec: one, dataset: dataset)?.run())
            #expect(table.rows.allSatisfy { $0.df != nil } && table.rows[1].ms != nil)
        }
    }

    @Test func stoppingTheTestFinishesItWithThePermutationsDrawn() throws {
        let dataset = try ExampleDataset.arapatPopulations.load()
        let spec = StructureSpec(level: "Population", permutations: 999, seed: 1)
        let analysis = try #require(StructureAnalysis(spec: spec, dataset: dataset))
        let stopped = try #require(analysis.run { $0 < 5 })
        #expect(stopped.spec.permutations == 5 && stopped.distribution?.values.count == 5)
        // The first five permutations are those of a five-permutation test with the same seed.
        var five = spec
        five.permutations = 5
        let planned = try #require(StructureAnalysis(spec: five, dataset: dataset)?.run())
        #expect(stopped.pValue == planned.pValue && stopped.report.methods == planned.report.methods)
    }

    @Test func stoppingAByLocusTestFinishesItToo() throws {
        let dataset = try ExampleDataset.arapatPopulations.load()
        let spec = StructureSpec(table: .perLocus, level: "Population", permutations: 99, seed: 3)
        let analysis = try #require(StructureAnalysis(spec: spec, dataset: dataset))
        let stopped = try #require(analysis.run { done, _ in done < 7 })
        var seven = spec
        seven.permutations = 7
        let planned = try #require(StructureAnalysis(spec: seven, dataset: dataset)?.run())
        #expect(stopped.spec.permutations == 7)
        #expect(stopped.locusRows.map(\.p) == planned.locusRows.map(\.p))
    }

    @Test func observingSeesEveryPermutedValue() throws {
        let dataset = try ExampleDataset.arapatPopulations.load()
        let spec = StructureSpec(statistic: .theta, locus: "LTRS", level: "Population", permutations: 49, seed: 8)
        let analysis = try #require(StructureAnalysis(spec: spec, dataset: dataset))
        var seen: [Double] = []
        let observed = try #require(analysis.run { done, value in
            seen.append(value)
            return done == seen.count
        })
        let plain = try #require(analysis.run())
        #expect(seen == observed.distribution?.values)
        #expect(observed.pValue == plain.pValue)
        #expect(analysis.run { done, _ in done < 10 }?.distribution?.values.count == 10)
    }

    // MARK: - Paternal gametes

    @Test func gametesByFamilyMatchTwoGener() throws {
        let dataset = try ExampleDataset.cornusFamilies.load()
        let spec = StructureSpec(sample: .paternalGametes, level: StructureSpec.familyLevel)
        let result = try #require(StructureAnalysis(spec: spec, dataset: dataset)?.run())
        let twoGener = try #require(TwoGenerAnalysis(matrix: dataset.matrix, design: dataset.parentage)?
            .run(options: AnalysisOptions(iterations: 0)))
        #expect(spec.statistic == .phiGametes)
        #expect(abs((result.statistic ?? .nan) - twoGener.phiFT) < 1e-12)
        #expect(result.rows.first?.source == "Family")
        #expect(result.report.results.contains("Φ_ST"))
        #expect(!result.report.results.contains("Φ_FT"))
        #expect(result.report.methods.contains("paternal gametes"))
    }

    @Test func oneGameteLocusUsesOnlyThatLocus() throws {
        let dataset = try ExampleDataset.cornusFamilies.load()
        let locus = dataset.matrix.loci[0].name
        let spec = StructureSpec(sample: .paternalGametes, locus: locus, level: StructureSpec.familyLevel)
        let result = try #require(StructureAnalysis(spec: spec, dataset: dataset)?.run())
        let twoGener = try #require(TwoGenerAnalysis(matrix: dataset.matrix, design: dataset.parentage, loci: [0])?
            .run(options: AnalysisOptions(iterations: 0)))
        #expect(abs((result.statistic ?? .nan) - twoGener.phiFT) < 1e-12)
    }

    // MARK: - Saving and export

    @Test func savedTablesRoundTrip() throws {
        let dataset = try ExampleDataset.arapatPopulations.load()
        let spec = StructureSpec(level: "Population", permutations: 19, seed: 2)
        let result = try #require(StructureAnalysis(spec: spec, dataset: dataset)?.run())
        let figure = try StoredFigure(title: spec.title, legend: result.legend, source: "Tests", result: result)
        #expect(figure.isTable && figure.formName == "table" && figure.generator == .amovaTable)
        #expect(figure.structureSpec == spec)
        #expect(figure.form == nil)
        let table = try #require(figure.table)
        #expect(table.columnNames == ["Source", "df", "SS", "MS", "sigma2", "Phi_ST", "P"])
        let code = try #require(figure.rCode)
        #expect(code.contains("#| label: tbl-amova-among-populations"))
        #expect(code.contains("kable( digits = 4"))
        #expect(figure.availableTableOutputs == TableExportOutput.allCases)

        let markdown = try #require(try figure.exportTable(.markdown))
        let text = String(decoding: markdown.data, as: UTF8.self)
        #expect(text.hasPrefix("| Source | df | SS | MS | sigma2 | Phi_ST | P |\n"
                               + "|:---|---:|---:|---:|---:|---:|---:|\n"))
        #expect(text.contains("{#tbl-amova-among-populations}"))
        #expect(markdown.suggestedName == "tbl-amova-among-populations")
        #expect(try figure.exportTable(.csv)?.contentType == .commaSeparatedText)
    }

    @Test func earlierSpecsReadAsTheTableTheyMade() throws {
        func decode(_ json: String) throws -> StructureSpec {
            try JSONDecoder().decode(StructureSpec.self, from: Data(json.utf8))
        }
        let all = try decode(#"{"level":"Population","permutations":0,"sample":"adults"}"#)
        #expect(all.table == .amova && all.statistic == .phiGenotypes && all.columns == [.theta, .phiGeneCopies,
                                                                                         .gst, .gstPrime, .dest])
        #expect(all.heterozygosity == .jost && StructureSpec(level: "Population").heterozygosity == .neiChesser)
        let one = try decode(#"{"level":"Population","locus":"LTRS","permutations":99,"sample":"adults","seed":3}"#)
        #expect(one.statistic == .theta && one.seed == 3 && one.isTested)
        let gametes = try decode(#"{"level":"Family","permutations":0,"sample":"paternalGametes"}"#)
        #expect(gametes.statistic == .phiGametes && gametes.columns == [.phiGametes])

        let spec = StructureSpec(table: .perLocus, columns: [.dest], heterozygosity: .uncorrected, level: "Population",
                                 thresholds: DifferentiationThresholds(destAlleles: 4))
        #expect(try decode(String(decoding: JSONEncoder().encode(spec), as: UTF8.self)) == spec)
    }

    @Test func validationKeepsChoicesTheSampleOffers() throws {
        let dataset = try ExampleDataset.cornusFamilies.load()
        let options = StructureOptions(dataset: dataset, sample: .paternalGametes)
        let checked = try #require(options.validated(StructureSpec(statistic: .theta, columns: [.gst],
                                                                   level: StructureSpec.familyLevel)))
        #expect(checked.sample == .paternalGametes && checked.statistic == .phiGametes
                && checked.columns == [.phiGametes])
    }

    @Test func byLocusGametesShowPhiOnly() throws {
        let dataset = try ExampleDataset.cornusFamilies.load()
        let spec = StructureSpec(sample: .paternalGametes, table: .perLocus, level: StructureSpec.familyLevel)
        let result = try #require(StructureAnalysis(spec: spec, dataset: dataset)?.run())
        #expect(result.dataTable.columnNames == ["Locus", "N", "Alleles", "Phi_ST"])
        #expect(result.locusRows.count == dataset.matrix.locusCount + 1)
        let pooled = try #require(StructureAnalysis(spec: StructureSpec(sample: .paternalGametes,
                                                                        level: StructureSpec.familyLevel),
                                                    dataset: dataset)?.run())
        #expect(abs((result.locusRows.last?.values[0] ?? .nan) - (pooled.statistic ?? .nan)) < 1e-12)
    }

    @Test func plotsAreNotTables() throws {
        let figure = StoredFigure(title: "He", formName: "bars")
        #expect(!figure.isTable && figure.availableTableOutputs.isEmpty)
        #expect(throws: PlotExportError.self) { _ = try figure.exportTable(.csv) }
    }
}
