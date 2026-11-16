//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DiversityFixtureTests.swift
//  PopulationGeneticsTests
//
//  Per-locus diversity (A, Ae, A95, He, Ho, Fis, Pe, Sh, Pex), the combined
//  multilocus Pex and Dm, checked against gstudio's genetic_diversity()
//  (1.15.5) on arapat, overall and within each Population
//  (Fixtures/generate_diversity_fixtures.R).
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import PopulationGenetics

struct DiversityFixtureTests {

    struct LocusValues: Decodable {
        let locus: String
        let A: Double?, Ae: Double?, A95: Double?, He: Double?, Ho: Double?
        let Fis: Double?, Pe: Double?, Sh: Double?, Pex: Double?

        func value(_ type: DiversityType) -> Double? {
            switch type {
            case .A: A
            case .Ae: Ae
            case .A95: A95
            case .He: He
            case .Ho: Ho
            case .Fis: Fis
            case .Pe: Pe
            case .Sh: Sh
            case .Pex: Pex
            default: nil
            }
        }
    }

    struct Stratum: Decodable {
        let stratum: String
        let individuals: Int
        let loci: [LocusValues]
        let pexMultilocus: Double?
        let dm: Double
    }

    struct Fixtures: Decodable {
        let overall: [LocusValues]
        let strata: [Stratum]
    }

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
    }

    private func load() throws -> (Fixtures, ImportedDataset) {
        let fixtures = try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url("diversity_fixtures.json")))
        let csv = try String(contentsOf: url("arapat_genotypes.csv"), encoding: .utf8)
        let dataset = try importPopulationTable(csv: csv, layout: PopulationImportLayout(strataColumns: ["Population"],
                                                                                         nameColumn: "ID"))
        return (fixtures, dataset)
    }

    private func check(_ expected: LocusValues, _ frequencies: AlleleFrequencies, _ context: String) {
        for type in DiversityType.frequencyStatistics {
            let swift = type.value(of: frequencies)
            if let r = expected.value(type) {
                #expect(swift.map { abs($0 - r) < 1e-12 } == true, "\(context) \(expected.locus) \(type)")
            } else {
                #expect(swift == nil, "\(context) \(expected.locus) \(type)")
            }
        }
    }

    @Test func perLocusDiversityMatchesGstudio() throws {
        let (fixtures, dataset) = try load()
        for (j, expected) in fixtures.overall.enumerated() {
            #expect(dataset.matrix.loci[j].name == expected.locus)
            check(expected, dataset.matrix.frequencies(atLocus: j), "overall")
        }
    }

    @Test func strataMatchGstudioIncludingDmAndPex() throws {
        let (fixtures, dataset) = try load()
        for stratum in fixtures.strata {
            let report = StratumReport(dataset: dataset, level: "Population", name: stratum.stratum)
            #expect(report.adults.count == stratum.individuals)
            for (j, expected) in stratum.loci.enumerated() {
                check(expected, dataset.matrix.frequencies(atLocus: j, over: report.adults), stratum.stratum)
                #expect((report.loci[j].shannon == nil) == (expected.Sh == nil))
                #expect(abs((report.loci[j].exclusion ?? 0) - (expected.Pex ?? 0)) < 1e-12)
            }
            #expect(abs((report.multilocusDiversity ?? .nan) - stratum.dm) < 1e-12, "\(stratum.stratum) Dm")
            // gstudio's combined Pex is NA when any locus is untyped; StratumReport combines the typed loci.
            if let pex = stratum.pexMultilocus {
                #expect(abs((report.multilocus.exclusion ?? .nan) - pex) < 1e-12, "\(stratum.stratum) Pex")
            }
        }
    }
}
