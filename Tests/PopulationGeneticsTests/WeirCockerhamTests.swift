//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  WeirCockerhamTests.swift
//  PopulationGeneticsTests
//
//  Checks Weir & Cockerham's θ and the multilocus AMOVA Φ_ST against the
//  values in Fixtures/structure_fixtures.json, which
//  Fixtures/generate_structure_fixtures.R makes from arapat with
//  hierfstat::wc() and gstudio's AMOVA distances.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
import Matrix
@testable import PopulationGenetics

/// One locus of `structure_fixtures.json`.
private struct WCFixture: Decodable {
    let locus: String
    let individuals: Int
    let strata: Int
    let nc: Double
    let sigmaAmong: Double
    let sigmaIndividuals: Double
    let sigmaWithin: Double
    let theta: Double
    let fIS: Double
    let fIT: Double
    let df: [Int]
    let ss: [Double]
    let ms: [Double]
}

/// The multilocus AMOVA of `structure_fixtures.json`.
private struct AMOVAFixture: Decodable {
    let individuals: [String]
    let dfAmong: Int
    let dfWithin: Int
    let ssAmong: Double
    let ssWithin: Double
    let ssTotal: Double
    let sigmaAmong: Double
    let sigmaWithin: Double
    let phiST: Double
}

/// The whole fixture file.
private struct StructureFixtures: Decodable {
    let weirCockerham: [WCFixture]
    let amova: AMOVAFixture
}

struct WeirCockerhamTests {

    // MARK: - Fixtures

    private func fixtureURL(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
    }

    private func fixtures() throws -> StructureFixtures {
        try JSONDecoder().decode(StructureFixtures.self,
                                 from: Data(contentsOf: fixtureURL("structure_fixtures.json")))
    }

    private func arapat() throws -> (matrix: GenotypeMatrix, populations: [String]) {
        let csv = try String(contentsOf: fixtureURL("arapat_genotypes.csv"), encoding: .utf8)
        let imported = try importPopulationTable(csv: csv, layout: PopulationImportLayout(strataColumns: ["Population"],
                                                                                          nameColumn: "ID"))
        let populations = imported.matrix.individuals.map { individual in
            imported.strata[individual.id]?.first(where: { $0.level == "Population" })?.name ?? ""
        }
        return (imported.matrix, populations)
    }

    private func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool {
        abs(a - b) <= tolerance * max(1, abs(b))
    }

    // MARK: - Weir & Cockerham

    @Test func thetaMatchesHierfstatAtEveryLocus() throws {
        let (matrix, populations) = try arapat()
        let expected = try fixtures().weirCockerham
        #expect(expected.count == 8)
        for fixture in expected {
            let j = try #require(matrix.loci.firstIndex(where: { $0.name == fixture.locus }))
            let analysis = try #require(WeirCockerhamAnalysis(column: matrix.columns[j], locus: fixture.locus,
                                                              ordinals: Array(0..<matrix.individualCount),
                                                              strata: populations))
            let outcome = try #require(analysis.run(options: AnalysisOptions(iterations: 0)))
            let d = outcome.decomposition
            #expect(d.individualCount == fixture.individuals, "\(fixture.locus) N")
            #expect(d.strataCount == fixture.strata, "\(fixture.locus) r")
            #expect([d.dfAmong, d.dfIndividuals, d.dfWithin, d.dfTotal] == fixture.df, "\(fixture.locus) df")
            #expect(close(d.nc, fixture.nc), "\(fixture.locus) nc")
            #expect(close(d.sigmaAmong, fixture.sigmaAmong), "\(fixture.locus) a")
            #expect(close(d.sigmaIndividuals, fixture.sigmaIndividuals), "\(fixture.locus) b")
            #expect(close(d.sigmaWithin, fixture.sigmaWithin), "\(fixture.locus) c")
            #expect(close(d.theta, fixture.theta), "\(fixture.locus) θ \(d.theta) vs \(fixture.theta)")
            #expect(close(d.fIS, fixture.fIS), "\(fixture.locus) F_IS")
            #expect(close(d.fIT, fixture.fIT), "\(fixture.locus) F_IT")
            #expect(close(d.ssAmong, fixture.ss[0]) && close(d.ssIndividuals, fixture.ss[1])
                    && close(d.ssWithin, fixture.ss[2]) && close(d.ssTotal, fixture.ss[3]), "\(fixture.locus) SS")
            #expect(close(d.msAmong, fixture.ms[0]) && close(d.msIndividuals, fixture.ms[1])
                    && close(d.msWithin, fixture.ms[2]), "\(fixture.locus) MS")
            #expect(outcome.distribution == nil)
            #expect(analysis.notes.isEmpty == (fixture.individuals == matrix.individualCount))
        }
    }

    @Test func permutationTestIsSeededAndStoppable() throws {
        let (matrix, populations) = try arapat()
        let analysis = try #require(WeirCockerhamAnalysis(column: matrix.columns[0], locus: "LTRS",
                                                          ordinals: Array(0..<matrix.individualCount),
                                                          strata: populations))
        let options = AnalysisOptions(iterations: 99, seed: 11)
        let first = try #require(analysis.run(options: options))
        let second = try #require(analysis.run(options: options))
        let p = try #require(first.pValue)
        #expect(p == second.pValue)
        #expect(p == 0.01)  // strong structure: no permutation reaches the observed θ
        #expect(first.tag == .weirCockerhamTheta && first.analysisType == .weirCockerham)

        var seen = 0
        #expect(analysis.run(options: options) { done in seen = done; return done < 10 }?.distribution?.values.count
                == 10)
        #expect(seen == 10)
    }

    @Test func tooFewStrataGiveNil() throws {
        let (matrix, _) = try arapat()
        let ordinals = Array(0..<matrix.individualCount)
        #expect(WeirCockerhamAnalysis(column: matrix.columns[0], locus: "LTRS", ordinals: ordinals,
                                      strata: Array(repeating: "All", count: ordinals.count)) == nil)
        #expect(WeirCockerhamAnalysis(column: matrix.columns[0], locus: "LTRS", ordinals: ordinals,
                                      strata: ["A"]) == nil)
    }

    @Test func reportIsFilled() throws {
        let (matrix, populations) = try arapat()
        var analysis = try #require(WeirCockerhamAnalysis(column: matrix.columns[0], locus: "LTRS",
                                                          ordinals: Array(0..<matrix.individualCount),
                                                          strata: populations))
        analysis.groupLabel = "populations"
        let report = try #require(analysis.perform(options: AnalysisOptions(iterations: 19, seed: 1))).report
        #expect(!(report.methods + report.results).contains("{"), "\(report.methods) \(report.results)")
        #expect(report.methods.contains("39 populations") && report.methods.contains("LTRS"))
        #expect(report.results.contains("θ = 0.526"))
    }

    // MARK: - Multilocus AMOVA

    @Test func multilocusPhiSTMatchesGstudio() throws {
        let (matrix, populations) = try arapat()
        let fixture = try fixtures().amova
        let rows = fixture.individuals.compactMap { name in matrix.individuals.firstIndex { $0.name == name } }
        #expect(rows.count == fixture.individuals.count)
        let distance = matrix.geneticDistance().submatrix(indices: rows)
        let analysis = try #require(AMOVAAnalysis(distance: distance, strata: rows.map { populations[$0] }))
        let outcome = try #require(analysis.run(options: AnalysisOptions(iterations: 0)))
        let d = outcome.decomposition
        #expect(outcome.statisticLabel == "Φ_ST")
        #expect(d.dfAmong == fixture.dfAmong && d.dfWithin == fixture.dfWithin)
        #expect(close(d.amongSS, fixture.ssAmong) && close(d.withinSS, fixture.ssWithin)
                && close(d.totalSS, fixture.ssTotal), "SS \(d.amongSS) \(d.withinSS) \(d.totalSS)")
        #expect(close(d.sigmaAmong, fixture.sigmaAmong) && close(d.sigmaWithin, fixture.sigmaWithin))
        #expect(close(outcome.phi, fixture.phiST), "Φ_ST \(outcome.phi) vs \(fixture.phiST)")
    }
}
