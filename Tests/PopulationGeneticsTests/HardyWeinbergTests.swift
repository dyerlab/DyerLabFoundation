//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  HardyWeinbergTests.swift
//  PopulationGeneticsTests
//
//  HardyWeinbergAnalysis against gstudio's hwe.test() (1.15.4) on arapat,
//  overall and per Population, and Matrix's chi-square and binomial tails
//  against R's pchisq() and binom.test() (Fixtures/generate_hwe_fixtures.R).
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
import Matrix
@testable import PopulationGenetics

struct HardyWeinbergTests {

    struct Row: Decodable {
        let stratum: String?
        let locus: String
        let statistic: Double
        let df: Int
        let p: Double
        let corrected: Bool
    }

    struct ChiSquare: Decodable { let x: Double; let df: Double; let p: Double }
    struct Binomial: Decodable { let k: Int; let n: Int; let prob: Double; let p: Double }

    struct Fixtures: Decodable {
        let overall: [Row]
        let strata: [Row]
        let chisq: [ChiSquare]
        let binom: [Binomial]
    }

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
    }

    private func load() throws -> (Fixtures, ImportedDataset) {
        let fixtures = try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url("hwe_fixtures.json")))
        let csv = try String(contentsOf: url("arapat_genotypes.csv"), encoding: .utf8)
        return (fixtures, try importPopulationTable(csv: csv, layout: PopulationImportLayout(
            strataColumns: ["Population"], nameColumn: "ID")))
    }

    private func check(_ outcome: HardyWeinbergOutcome?, _ r: Row) {
        let context = "\(r.stratum ?? "all") \(r.locus)"
        guard let outcome else {
            Issue.record("no test for \(context)")
            return
        }
        #expect(abs(outcome.statistic - r.statistic) <= 1e-10 * max(1, r.statistic), "\(context)")
        #expect(outcome.degreesOfFreedom == r.df, "\(context)")
        #expect(abs((outcome.pValue ?? .nan) - r.p) <= 1e-10 * max(r.p, 1e-300) + 1e-14, "\(context)")
        #expect(outcome.isCorrected == r.corrected, "\(context)")
    }

    @Test func testsMatchGstudioOverallAndByStratum() throws {
        let (fixtures, dataset) = try load()
        let overall = HardyWeinbergAnalysis.tests(dataset: dataset)
        #expect(overall.count == fixtures.overall.count)
        for r in fixtures.overall { check(overall.first { $0.locus == r.locus }?.run(), r) }

        let strata = HardyWeinbergAnalysis.tests(dataset: dataset, level: "Population")
        #expect(strata.count == fixtures.strata.count)
        for r in fixtures.strata {
            check(strata.first { $0.stratum == r.stratum && $0.locus == r.locus }?.run(), r)
        }
    }

    @Test func expectedCountsFollowHardyWeinbergProportions() throws {
        let (_, dataset) = try load()
        let test = try #require(HardyWeinbergAnalysis(matrix: dataset.matrix, locus: 1))
        #expect(abs(test.counts.reduce(0) { $0 + $1.expected } - Double(test.sampleSize)) < 1e-9)
        #expect(test.counts.count == test.alleleCount * (test.alleleCount + 1) / 2)
        let run = try #require(test.perform())
        #expect(run.report.results.contains("χ²"))
        #expect(run.report.methods.contains("\(test.sampleSize) individuals"))
    }

    @Test func smallSamplesAndRareGenotypesAreNoted() throws {
        let (_, dataset) = try load()
        let small = try #require(HardyWeinbergAnalysis.tests(dataset: dataset, level: "Population").first)
        #expect(small.notes.contains { $0.message.contains("Under 50 individuals") })
        #expect(small.notes.contains { $0.message.contains("continuity correction") })
    }

    @Test func chiSquareAndBinomialTailsMatchR() throws {
        let (fixtures, _) = try load()
        for c in fixtures.chisq {
            let p = chiSquareUpperTail(c.x, degreesOfFreedom: c.df)
            #expect(abs(p - c.p) <= 1e-12 * max(c.p, 1e-300) + 1e-15, "χ² \(c.x) df \(c.df): \(p) vs \(c.p)")
        }
        for b in fixtures.binom {
            let p = binomialUpperTail(successes: b.k, trials: b.n, probability: b.prob)
            #expect(abs(p - b.p) <= 1e-10 * max(b.p, 1e-300) + 1e-15, "binom \(b.k)/\(b.n) p \(b.prob)")
        }
    }
}
