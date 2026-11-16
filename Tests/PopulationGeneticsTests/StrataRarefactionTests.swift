//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StrataRarefactionTests.swift
//  PopulationGeneticsTests
//
//  StrataRarefactionAnalysis against gstudio's rarefaction.test() (1.15.5)
//  on arapat by Population, every resampled value draw for draw
//  (Fixtures/generate_strata_rarefaction_fixtures.R).
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
import Matrix
@testable import PopulationGenetics

struct StrataRarefactionTests {

    struct FRow: Decodable {
        let stratum: String, locus: String, mode: String
        let n: Int?, size: Int?
        let observed: Double?, estimate: Double?, low: Double?, high: Double?
        let values: [Double?]
    }
    struct FCase: Decodable {
        let seed: UInt64
        let strata: [String]
        let loci: [String]
        let modes: [String]
        let nperm: Int
        let size: Int?
        let confLevel: Double
        let naRm: Bool
        let rows: [FRow]
    }

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
    }

    private func dataset() throws -> ImportedDataset {
        let csv = try String(contentsOf: url("arapat_genotypes.csv"), encoding: .utf8)
        return try importPopulationTable(csv: csv, layout: PopulationImportLayout(strataColumns: ["Population"],
                                                                                  nameColumn: "ID"))
    }

    private func close(_ a: Double?, _ b: Double?) -> Bool {
        switch (a, b) {
        case (nil, nil): true
        case let (a?, b?): abs(a - b) <= 1e-10 * max(1, abs(b))
        default: false
        }
    }

    @Test(arguments: ["smallest", "fixed"])
    func matchesGstudio(_ name: String) throws {
        let cases = try JSONDecoder().decode([String: FCase].self,
                                             from: Data(contentsOf: url("strata_rarefaction_fixtures.json")))
        let c = try #require(cases[name])
        let data = try dataset()
        let loci = try c.loci.map { try #require(data.matrix.locusIndex(named: $0)) }
        let statistics = try c.modes.map { mode in
            try #require(StrataRarefactionAnalysis.statistics.first { $0.rawValue == mode })
        }
        let analysis = try #require(StrataRarefactionAnalysis(
            dataset: data, level: "Population", strata: c.strata, loci: loci, statistics: statistics, size: c.size,
            confidenceLevel: c.confLevel, dropsMissingLoci: c.naRm))
        let result = try #require(analysis.run(options: AnalysisOptions(iterations: c.nperm, seed: c.seed)))
        try #require(result.rows.count == c.rows.count)

        for (swift, r) in zip(result.rows, c.rows) {
            let context = "\(name) \(r.stratum) \(r.locus) \(r.mode)"
            #expect(swift.stratum == r.stratum && (swift.locus ?? "Multilocus") == r.locus
                    && swift.statistic.rawValue == r.mode, "\(context) order")
            #expect(swift.individuals == r.n && swift.size == r.size, "\(context) sizes")
            #expect(close(swift.observed, r.observed), "\(context) observed \(swift.observed ?? .nan)")
            #expect(close(swift.estimate, r.estimate), "\(context) estimate")
            #expect(close(swift.interval?.lowerBound, r.low) && close(swift.interval?.upperBound, r.high),
                    "\(context) interval")
            let values = swift.values.map { $0.isFinite ? $0 : nil }
            #expect(values.count == r.values.count && zip(values, r.values).allSatisfy(close), "\(context) draws")
        }
    }

    @Test func reportAndGuards() throws {
        let data = try dataset()
        #expect(StrataRarefactionAnalysis(dataset: data, level: nil) == nil)              // no strata, no size
        #expect(StrataRarefactionAnalysis(dataset: data, level: "Population", statistics: [.Dm]) == nil)
        let analysis = try #require(StrataRarefactionAnalysis(dataset: data, level: "Population",
                                                              statistics: [.Ae, .Fis]))
        let result = try #require(analysis.run(options: AnalysisOptions(iterations: 10, seed: 1)))
        #expect(result.report.methods.contains("subsampled without replacement"))
        #expect(result.report.results.contains("Rarefied multilocus"))
        #expect(!result.report.methods.contains("{"))
        #expect(result.rows(for: .Ae, locus: nil).count == analysis.strata.count)
        let long = try #require(result.distributionTable(for: .Ae))
        #expect(long.rowCount == result.rows(for: .Ae, locus: nil).reduce(0) { $0 + $1.values.filter(\.isFinite).count })
        #expect(long.columnNames.contains("stratum") && long.columnNames.contains("Ae"))
        #expect(try #require(result.summaryTable(for: .Fis)).rowCount == analysis.strata.count)

        let whole = try #require(StrataRarefactionAnalysis(dataset: data, level: nil, statistics: [.A], size: 10))
        #expect(whole.strata == ["All"])
        #expect(whole.run(options: AnalysisOptions(iterations: 0)) == nil)
    }
}
