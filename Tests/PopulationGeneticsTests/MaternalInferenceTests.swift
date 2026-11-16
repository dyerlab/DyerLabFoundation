//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MaternalInferenceTests.swift
//  PopulationGeneticsTests
//
//  Missing maternal genotypes reconstructed from offspring, checked against
//  gstudio's PhiFT (`.infer_maternal()`, 1.15.5) on the cornus families with
//  the two mothers that have offspring blanked at every locus
//  (Fixtures/generate_maternal_inference_fixtures.R).
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
import Matrix
@testable import PopulationGenetics

struct MaternalInferenceTests {

    struct Expected: Decodable {
        let family: String
        let locus: String
        let offspring: Int
        let genotype: String?
        let alternative: String?
        let likelihoodRatio: Ratio
        let used: Bool
    }

    /// A ratio, which jsonlite writes as the string "Inf" when infinite.
    struct Ratio: Decodable {
        let value: Double
        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) {
                value = text == "Inf" ? .infinity : .nan
            } else {
                value = try container.decode(Double.self)
            }
        }
    }

    struct Fixtures: Decodable { let inferences: [Expected] }

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
    }

    private func blanked() throws -> ImportedDataset {
        try importMicrosatTable(csv: String(contentsOf: url("maternal_inference_genotypes.csv"), encoding: .utf8),
                                layout: GenotypeImportLayout(familyColumn: "ID", offspringColumn: "OffID",
                                                             latitudeColumn: "Latitude", longitudeColumn: "Longitude"))
    }

    @Test func reconstructionsMatchGstudio() throws {
        let expected = try JSONDecoder().decode(Fixtures.self,
                                                from: Data(contentsOf: url("maternal_inference_fixtures.json")))
        let dataset = try blanked()
        let analysis = try #require(TwoGenerAnalysis(matrix: dataset.matrix, design: dataset.parentage))
        let inferred = analysis.maternalInferences
        #expect(inferred.count == expected.inferences.count)
        for (swift, r) in zip(inferred, expected.inferences) {
            #expect(swift.family == r.family && swift.locus == r.locus)
            #expect(swift.offspringCount == r.offspring)
            #expect(swift.genotype?.description == r.genotype)
            #expect(swift.genotype?.isEstimated == true)
            #expect(swift.alternative?.description == r.alternative)
            #expect(swift.isUsed == r.used)
            let ratio = try #require(swift.likelihoodRatio)
            if r.likelihoodRatio.value.isInfinite {
                #expect(ratio == .infinity)
            } else {
                #expect(abs(ratio / r.likelihoodRatio.value - 1) < 1e-9, "\(r.family) \(r.locus)")
            }
        }
    }

    @Test func usedReconstructionsRecoverGametesAndTheRestAreImputed() throws {
        let dataset = try blanked()
        let original = try ExampleDataset.cornusFamilies.load()
        let withMothers = try #require(TwoGenerAnalysis(matrix: original.matrix, design: original.parentage))
        let analysis = try #require(TwoGenerAnalysis(matrix: dataset.matrix, design: dataset.parentage))
        let unused = analysis.maternalInferences.filter { !$0.isUsed }
        #expect(unused.count == 2)
        // Only the offspring of mothers left unreconstructed are imputed beyond those already missing.
        #expect(analysis.gametes.imputedCount - withMothers.gametes.imputedCount
                == unused.reduce(0) { $0 + $1.offspringCount })
        #expect(analysis.notes.filter { $0.logType == .warning && $0.message.contains("short of 20") }.count == 2)
        #expect(analysis.notes.contains { $0.logType == .assumption && $0.message.contains("was inferred from 20") })
        let report = try #require(analysis.perform(options: AnalysisOptions(iterations: 0)))
        #expect(report.report.methods.contains("reconstructed from the offspring by maximum likelihood"))
    }

    @Test func noMissingMothersMeansNoInferences() throws {
        let dataset = try ExampleDataset.cornusFamilies.load()
        let analysis = try #require(TwoGenerAnalysis(matrix: dataset.matrix, design: dataset.parentage))
        #expect(analysis.maternalInferences.isEmpty)
    }

    @Test func estimatedFlagDecodesFromOlderGenotypes() throws {
        let old = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","leftAllele":"A","rightAllele":"B","#
            + #""leftLineage":0,"rightLineage":0}"#
        let genotype = try JSONDecoder().decode(Genotype.self, from: Data(old.utf8))
        #expect(!genotype.isEstimated)
        let estimated = Genotype(leftAllele: "A", rightAllele: "B", isEstimated: true)
        let round = try JSONDecoder().decode(Genotype.self, from: JSONEncoder().encode(estimated))
        #expect(round.isEstimated)
        #expect(round == genotype)
    }
}
