//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StructureFixtureTests.swift
//  PopulationGeneticsTests
//
//  The allele-count structure engine against generate_structure_fixtures.R:
//  gene-copy and genotype AMOVAs per locus and as ratios of sums, Weir &
//  Cockerham's multilocus θ (hierfstat), and Hs, Ht, Gst, G′st and Dest by
//  each estimator (Jost's form checked against mmod in the script, Nei &
//  Chesser's against hierfstat's basic.stats, and the uncorrected one direct).
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
import Matrix
@testable import PopulationGenetics

/// A two-level AMOVA of the fixture file.
private struct TwoLevelFixture: Decodable {
    let units: Int
    let strata: Int
    let dfAmong: Int
    let dfWithin: Int
    let ssAmong: Double
    let ssWithin: Double
    let sigmaAmong: Double
    let sigmaWithin: Double
    let phiST: Double
}

/// One locus's AMOVAs.
private struct AMOVALocusFixture: Decodable {
    let locus: String
    let alleles: Int
    let geneCopies: TwoLevelFixture
    let genotypes: TwoLevelFixture
}

/// One locus's differentiation.
private struct DifferentiationFixture: Decodable {
    let locus: String
    let individuals: Int
    let strata: Int
    let alleles: Int
    let hs: Double
    let ht: Double
    let gst: Double
    let gstPrime: Double
    let dest: Double
}

/// The fixture file's new sections.
private struct Fixtures: Decodable {
    struct WC: Decodable { let locus: String; let theta: Double; let fIS: Double; let fIT: Double }
    struct WCMultilocus: Decodable { let theta: Double; let fIS: Double; let fIT: Double }
    struct AMOVAMultilocus: Decodable { let geneCopies: Double; let genotypes: Double }
    struct DifferentiationMultilocus: Decodable { let gst: Double; let gstPrime: Double; let dest: Double }

    let weirCockerham: [WC]
    let weirCockerhamMultilocus: WCMultilocus
    let amovaLocus: [AMOVALocusFixture]
    let amovaMultilocus: AMOVAMultilocus
    let differentiation: [DifferentiationFixture]
    let differentiationMultilocus: DifferentiationMultilocus
    let differentiationNeiChesser: [DifferentiationFixture]
    let differentiationNeiChesserMultilocus: DifferentiationMultilocus
    let differentiationUncorrected: [DifferentiationFixture]
    let differentiationUncorrectedMultilocus: DifferentiationMultilocus

    /// The per-locus and multilocus values of one Hs and Ht estimator.
    ///
    /// - Parameter estimator: The estimator.
    /// - Returns: R's per-locus and multilocus values for it.
    func differentiation(_ estimator: StructureSpec.Heterozygosity)
        -> (loci: [DifferentiationFixture], multilocus: DifferentiationMultilocus) {
        switch estimator {
        case .jost: (differentiation, differentiationMultilocus)
        case .neiChesser: (differentiationNeiChesser, differentiationNeiChesserMultilocus)
        case .uncorrected: (differentiationUncorrected, differentiationUncorrectedMultilocus)
        }
    }
}

struct StructureFixtureTests {

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
    }

    private func fixtures() throws -> Fixtures {
        try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url("structure_fixtures.json")))
    }

    private func dataset() throws -> ImportedDataset {
        let csv = try String(contentsOf: url("arapat_genotypes.csv"), encoding: .utf8)
        return try importPopulationTable(csv: csv, layout: PopulationImportLayout(strataColumns: ["Population"],
                                                                                  nameColumn: "ID"))
    }

    private func close(_ a: Double?, _ b: Double, _ tolerance: Double = 1e-9) -> Bool {
        guard let a else { return false }
        return abs(a - b) <= tolerance * max(1, abs(b))
    }

    private func analysis(_ spec: StructureSpec) throws -> StructureAnalysis {
        try #require(StructureAnalysis(spec: spec, dataset: try dataset()))
    }

    // MARK: - AMOVA

    @Test func perLocusAMOVAsMatchR() throws {
        let analysis = try analysis(StructureSpec(level: "Population"))
        var workspace = analysis.data.makeWorkspace()
        let components = analysis.evaluate(analysis.data.partition, workspace: &workspace).loci
        for fixture in try fixtures().amovaLocus {
            let l = try #require(analysis.data.loci.firstIndex { $0.name == fixture.locus })
            let locus = try #require(components[l])
            #expect(locus.alleles == fixture.alleles, "\(fixture.locus) alleles")
            for (parts, expected, kind) in [(locus.geneCopies, fixture.geneCopies, "copies"),
                                            (locus.genotypes, fixture.genotypes, "genotypes")] {
                let parts = try #require(parts)
                #expect(parts.df == [expected.dfAmong, expected.dfWithin], "\(fixture.locus) \(kind) df")
                #expect(close(parts.ss[0], expected.ssAmong) && close(parts.ss[1], expected.ssWithin),
                        "\(fixture.locus) \(kind) SS \(parts.ss)")
                #expect(close(parts.sigma[0], expected.sigmaAmong) && close(parts.sigma[1], expected.sigmaWithin),
                        "\(fixture.locus) \(kind) σ²")
                #expect(close(parts.amongShare, expected.phiST), "\(fixture.locus) \(kind) Φ_ST")
            }
        }
    }

    @Test func multilocusPhiIsARatioOfSums() throws {
        let expected = try fixtures().amovaMultilocus
        let copies = try #require(try analysis(StructureSpec(statistic: .phiGeneCopies, level: "Population")).run())
        let genotypes = try #require(try analysis(StructureSpec(statistic: .phiGenotypes, level: "Population")).run())
        #expect(close(copies.statistic, expected.geneCopies), "copies \(copies.statistic ?? .nan)")
        #expect(close(genotypes.statistic, expected.genotypes), "genotypes \(genotypes.statistic ?? .nan)")
        // Arapat's loci were genotyped in different numbers of individuals (ZMP in only 38 of the 39
        // populations), so the sum has no single df.
        #expect(copies.rows.allSatisfy { $0.df == nil && $0.ms == nil } && copies.rows[0].sigma != nil)
        #expect(copies.report.notes.contains { $0.message.contains("no single df") })
    }

    @Test func multilocusThetaMatchesHierfstat() throws {
        let expected = try fixtures().weirCockerhamMultilocus
        let result = try #require(try analysis(StructureSpec(statistic: .theta, level: "Population")).run())
        #expect(close(result.statistic, expected.theta))
        #expect(result.rows.map(\.source) == ["Population", "Individual", "Error", "Total"])
        #expect(close(result.rows[1].statistic, expected.fIS) && close(result.rows[3].statistic, expected.fIT))
    }

    // MARK: - By locus

    @Test func byLocusTableMatchesR() throws {
        let fixtures = try fixtures()
        let columns: [StructureSpec.Column] = [.theta, .fIS, .fIT, .phiGeneCopies, .phiGenotypes, .gst, .gstPrime,
                                               .dest]
        let spec = StructureSpec(table: .perLocus, columns: columns, heterozygosity: .jost, level: "Population")
        let result = try #require(try analysis(spec).run())
        #expect(result.locusRows.count == 9 && result.locusRows.last?.locus == StructureLocusRow.multilocusName)
        func value(_ row: StructureLocusRow, _ column: StructureSpec.Column) -> Double? {
            row.values[columns.firstIndex(of: column) ?? 0]
        }
        for fixture in fixtures.differentiation {
            let row = try #require(result.locusRows.first { $0.locus == fixture.locus })
            let wc = try #require(fixtures.weirCockerham.first { $0.locus == fixture.locus })
            let amova = try #require(fixtures.amovaLocus.first { $0.locus == fixture.locus })
            #expect(row.units == fixture.individuals && row.alleles == fixture.alleles, "\(fixture.locus) N")
            #expect(close(row.hs, fixture.hs) && close(row.ht, fixture.ht), "\(fixture.locus) Hs/Ht")
            #expect(close(value(row, .gst), fixture.gst), "\(fixture.locus) Gst")
            #expect(close(value(row, .gstPrime), fixture.gstPrime), "\(fixture.locus) G′st")
            #expect(close(value(row, .dest), fixture.dest), "\(fixture.locus) Dest")
            #expect(close(value(row, .theta), wc.theta) && close(value(row, .fIS), wc.fIS)
                    && close(value(row, .fIT), wc.fIT), "\(fixture.locus) W&C")
            #expect(close(value(row, .phiGeneCopies), amova.geneCopies.phiST)
                    && close(value(row, .phiGenotypes), amova.genotypes.phiST), "\(fixture.locus) Φ")
        }
        let all = try #require(result.locusRows.last)
        let m = fixtures.differentiationMultilocus
        #expect(close(value(all, .gst), m.gst) && close(value(all, .gstPrime), m.gstPrime)
                && close(value(all, .dest), m.dest), "multilocus differentiation")
        #expect(close(value(all, .theta), fixtures.weirCockerhamMultilocus.theta))
        #expect(close(value(all, .phiGeneCopies), fixtures.amovaMultilocus.geneCopies))
        #expect(close(all.hs, fixtures.differentiation.map(\.hs).reduce(0, +) / 8))
    }

    @Test(arguments: StructureSpec.Heterozygosity.allCases)
    func everyHeterozygosityEstimatorMatchesR(_ estimator: StructureSpec.Heterozygosity) throws {
        let (loci, multilocus) = try fixtures().differentiation(estimator)
        let columns: [StructureSpec.Column] = [.gst, .gstPrime, .dest]
        let spec = StructureSpec(table: .perLocus, columns: columns, heterozygosity: estimator, level: "Population")
        let result = try #require(try analysis(spec).run())
        for fixture in loci {
            let row = try #require(result.locusRows.first { $0.locus == fixture.locus })
            #expect(close(row.hs, fixture.hs) && close(row.ht, fixture.ht), "\(fixture.locus) Hs/Ht")
            #expect(close(row.values[0], fixture.gst) && close(row.values[1], fixture.gstPrime)
                    && close(row.values[2], fixture.dest), "\(fixture.locus) differentiation")
        }
        let all = try #require(result.locusRows.last)
        #expect(close(all.values[0], multilocus.gst) && close(all.values[1], multilocus.gstPrime)
                && close(all.values[2], multilocus.dest), "multilocus differentiation")
        #expect(result.report.methods.contains(estimator.methods) && result.legend.contains(estimator.methods))
    }

    @Test func flagsFollowTheThresholds() throws {
        let spec = StructureSpec(table: .perLocus, heterozygosity: .jost, level: "Population")
        let result = try #require(try analysis(spec).run())
        let flagged = result.locusRows.filter { !$0.concerns.isEmpty }.map(\.locus)
        // Gst: AML (13), ATPS (10), MP20 (19) alleles; Dest: the three two-allele loci and EN's Hs of 0.257.
        #expect(Set(flagged) == ["LTRS", "EN", "EF", "ZMP", "AML", "ATPS", "MP20"], "\(flagged)")
        #expect(result.locusRows.first { $0.locus == "AML" }?.concerns == ["Gst: 13 alleles"])
        #expect(result.locusRows.first { $0.locus == "EN" }?.concerns.first?.hasPrefix("Dest: Hs 0.25") == true)
        #expect(result.warnings.count == 2 && result.legend.contains("⚠︎ Gst is flagged at AML, ATPS, MP20"))
        #expect(result.report.notes.filter { $0.logType == .warning }.count == 2)
        #expect(result.dataTable.columnNames.last == StructureResult.concernColumn)

        var relaxed = spec
        relaxed.thresholds = DifferentiationThresholds(gstAlleles: 50, gstDiversity: 1, destAlleles: 0,
                                                       destDiversity: 0)
        let quiet = try #require(try analysis(relaxed).run())
        #expect(quiet.warnings.isEmpty && !quiet.dataTable.columnNames.contains(StructureResult.concernColumn))

        let options = StructureOptions(dataset: try dataset(), sample: .adults)
        #expect(options.concerns(for: spec)?.contains("AML (13)") == true)
        #expect(options.concerns(for: StructureSpec(level: "Population")) == nil)
    }

    @Test func byLocusTestsEveryCell() throws {
        let spec = StructureSpec(table: .perLocus, columns: [.theta, .fIS, .gst], level: "Population",
                                 permutations: 19, seed: 4)
        let analysis = try analysis(spec)
        var seen: [Double] = []
        let result = try #require(analysis.run { done, value in
            seen.append(value)
            return done == seen.count
        })
        #expect(seen == result.distribution?.values)
        #expect(result.locusRows.allSatisfy { $0.p.count == 2 })
        #expect(result.locusRows.allSatisfy { $0.p.allSatisfy { $0 == 0.05 } })   // strong structure everywhere
        #expect(result.pValue == 0.05 && result.statistic == result.locusRows.last?.values[0])
        #expect(result.dataTable.columnNames == ["Locus", "N", "Alleles", "Hs", "Ht", "theta", "P_theta", "F_IS",
                                                 "Gst", "P_Gst", "Warning"])
        #expect(analysis.run()?.locusRows == result.locusRows)
        #expect(analysis.run { done, _ in done < 3 }?.spec.permutations == 3)
    }
}
