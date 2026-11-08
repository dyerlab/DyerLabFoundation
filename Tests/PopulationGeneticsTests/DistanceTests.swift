//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DistanceTests.swift
//  PopulationGeneticsTests
//
//  Great-circle and genetic distance matrices against gstudio (Fixtures/generate_distance_fixtures.R), the choices a
//  dataset offers, and the matrices' storage with their spec.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix
import Testing
@testable import PopulationGenetics

private struct DistanceFixture: Decodable {
    let names: [String]
    let values: [Double]
}

private struct GeneticFixtures: Decodable {
    let completeIndividuals: [String]
    let amovaFirst30: DistanceFixture
    let brayFirst30: DistanceFixture
    let nei: DistanceFixture
    let cavalli: DistanceFixture
    let dps: DistanceFixture
    let euclidean: DistanceFixture
    let phiST: DistanceFixture
    let cgd: DistanceFixture
}

private struct DistanceFixtures: Decodable {
    let earthRadius: Double
    let genetic: GeneticFixtures
    let arapatPopulation: DistanceFixture
    let arapatSpecies: DistanceFixture
    let arapatCluster: DistanceFixture
    let arapatFirst30Individuals: DistanceFixture
    let cornusMothers: DistanceFixture
}

struct DistanceTests {

    private func fixtures() throws -> DistanceFixtures {
        try DistanceFixtureData.decoder.decode(DistanceFixtures.self, from: Data(contentsOf: DistanceFixtureData.url))
    }

    /// Checks every pair a fixture names against a result, which may hold more units than the fixture.
    private func expectMatches(_ result: DistanceResult, _ fixture: DistanceFixture,
                               sourceLocation: SourceLocation = #_sourceLocation) {
        let n = fixture.names.count
        for i in 0..<n {
            for j in 0..<n where i != j {
                let expected = fixture.values[i * n + j]
                guard let found = result.matrix[fixture.names[i], fixture.names[j]] else {
                    Issue.record("\(fixture.names[i]) or \(fixture.names[j]) is missing", sourceLocation: sourceLocation)
                    return
                }
                if expected.isInfinite {
                    #expect(found == expected, "\(fixture.names[i])–\(fixture.names[j])", sourceLocation: sourceLocation)
                } else {
                    #expect(abs(found - expected) <= 1e-9 * max(1, abs(expected)),
                            "\(fixture.names[i])–\(fixture.names[j]): \(found) vs \(expected)",
                            sourceLocation: sourceLocation)
                }
            }
        }
    }

    private func run(_ level: String, _ dataset: ImportedDataset,
                     measure: DistanceSpec.Measure = .greatCircle) throws -> DistanceResult {
        try #require(DistanceAnalysis(spec: DistanceSpec(measure: measure, level: level), dataset: dataset)?.run())
    }

    // MARK: - Against gstudio

    @Test func strataMatchGstudio() throws {
        let fixtures = try fixtures()
        #expect(fixtures.earthRadius == GreatCircle.earthRadius)
        let arapat = try ExampleDataset.arapatPopulations.load()
        let population = try run("Population", arapat)
        #expect(population.matrix.groupNames == fixtures.arapatPopulation.names, "strata keep their first order")
        expectMatches(population, fixtures.arapatPopulation)
        expectMatches(try run("Species", arapat), fixtures.arapatSpecies)
        expectMatches(try run("Cluster", arapat), fixtures.arapatCluster)
        #expect(population.groups == nil && population.omitted.isEmpty)
    }

    @Test func individualsMatchGstudio() throws {
        let fixtures = try fixtures()
        let individuals = try run(DistanceSpec.individualsLevel, try ExampleDataset.arapatPopulations.load())
        #expect(individuals.count == 363)
        expectMatches(individuals, fixtures.arapatFirst30Individuals)
        #expect(individuals.groups?.first == "88", "each row is marked with its innermost stratum")
    }

    @Test func parentOffspringDistancesAreAmongMothers() throws {
        let fixtures = try fixtures()
        let cornus = try ExampleDataset.cornusFamilies.load()
        let mothers = try run(DistanceSpec.individualsLevel, cornus)
        #expect(mothers.count == fixtures.cornusMothers.names.count)
        expectMatches(mothers, fixtures.cornusMothers)
        #expect(mothers.name == "Great-circle distance among mothers")
    }

    // MARK: - Genetic distances against gstudio

    @Test func individualGeneticDistancesMatchGstudio() throws {
        let fixtures = try fixtures().genetic
        let complete = try DistanceFixtureData.completeArapat()
        #expect(complete.matrix.individuals.map(\.name) == fixtures.completeIndividuals)
        let amova = try run(DistanceSpec.individualsLevel, complete, measure: .amova)
        #expect(amova.count == fixtures.completeIndividuals.count && amova.spec.measure.units == nil)
        expectMatches(amova, fixtures.amovaFirst30)
        expectMatches(try run(DistanceSpec.individualsLevel, complete, measure: .bray), fixtures.brayFirst30)
    }

    @Test func strataGeneticDistancesMatchGstudio() throws {
        let fixtures = try fixtures().genetic
        let complete = try DistanceFixtureData.completeArapat()
        let nei = try run("Population", complete, measure: .nei)
        #expect(nei.matrix.groupNames == fixtures.nei.names, "strata keep their first order")
        expectMatches(nei, fixtures.nei)
        expectMatches(try run("Population", complete, measure: .cavalli), fixtures.cavalli)
        expectMatches(try run("Population", complete, measure: .dps), fixtures.dps)
        expectMatches(try run("Population", complete, measure: .euclidean), fixtures.euclidean)
        expectMatches(try run("Population", complete, measure: .phiST), fixtures.phiST)
    }

    @Test func conditionalGeneticDistanceMatchesGstudio() throws {
        let fixtures = try fixtures().genetic
        let cgd = try run("Population", try DistanceFixtureData.completeArapat(), measure: .cgd)
        #expect(cgd.matrix.groupNames == fixtures.cgd.names)
        #expect(cgd.omissionReason == "fewer than 3 genotyped individuals" && cgd.omitted.count == 1)
        expectMatches(cgd, fixtures.cgd)
    }

    @Test func missingGenotypesAreLeftOutRatherThanCountedAsZero() throws {
        // 88_11A is missing WNT, ZMP and AML: Bray-Curtis averages over the 5 loci it shares with 88_12A.
        let arapat = try ExampleDataset.arapatPopulations.load()
        let bray = try run(DistanceSpec.individualsLevel, arapat, measure: .bray)
        let pair = try #require(bray.matrix["88_11A", "88_12A"])
        // Shared: LTRS 1, EN 0 (02:04 vs 01:01), EF 0.5, ATPS 1, MP20 1, so 3.5 of 5 loci.
        #expect(abs(pair - (1 - 3.5 / 5)) < 1e-12)
        let all = try run("Population", arapat, measure: .nei)
        #expect(all.count == 39 && all.pairwiseValues.allSatisfy(\.isFinite))
    }

    @Test func measuresWorkOnlyAtTheirLevels() throws {
        let arapat = try ExampleDataset.arapatPopulations.load()
        #expect(DistanceAnalysis(spec: DistanceSpec(measure: .amova, level: "Population"), dataset: arapat) == nil)
        #expect(DistanceAnalysis(spec: DistanceSpec(measure: .nei), dataset: arapat) == nil)
        let options = DistanceOptions(dataset: arapat)
        #expect(options.measures(at: DistanceSpec.individualsLevel) == [.greatCircle, .amova, .bray])
        #expect(options.measures(at: "Population") == [.greatCircle, .nei, .cavalli, .dps, .euclidean, .phiST, .cgd])
        #expect(options.measures(at: "Species") == [.greatCircle, .nei, .cavalli, .dps, .euclidean, .phiST, .cgd])
        let cornus = DistanceOptions(dataset: try ExampleDataset.cornusFamilies.load())
        #expect(!cornus.offers(.cgd, at: DistanceSpec.individualsLevel) && cornus.offers(.bray, at: "Individuals"))
        let moved = options.spec(DistanceSpec(measure: .nei, level: "Population"), movedTo: DistanceSpec.individualsLevel)
        #expect(moved == DistanceSpec(measure: .greatCircle, level: DistanceSpec.individualsLevel))
        #expect(DistanceSpec(measure: .nei, level: "Population").json == #"{"level":"Population","measure":"nei"}"#)
    }

    // MARK: - Choices

    @Test func optionsListTheLocatedLevels() throws {
        let arapat = DistanceOptions(dataset: try ExampleDataset.arapatPopulations.load())
        #expect(arapat.levels == [DistanceSpec.individualsLevel, "Species", "Cluster", "Population"])
        #expect(arapat.unitCount(at: "Population", for: .greatCircle) == 39)
        #expect(arapat.unitCount(at: DistanceSpec.individualsLevel, for: .amova) == 363)
        #expect(arapat.defaultSpec == DistanceSpec(level: "Population"))
        #expect(arapat.label(for: DistanceSpec.individualsLevel) == "Individuals")

        let cornus = DistanceOptions(dataset: try ExampleDataset.cornusFamilies.load())
        #expect(cornus.isParentOffspring && cornus.label(for: DistanceSpec.individualsLevel) == "Mothers")
        #expect(cornus.levels.first == DistanceSpec.individualsLevel)
    }

    @Test func noCoordinatesOfferNothing() {
        let matrix = GenotypeMatrix(individuals: [Individual(name: "a"), Individual(name: "b")], loci: [], columns: [])
        let dataset = ImportedDataset(matrix: matrix, parentage: ParentageDesign(families: []))
        let options = DistanceOptions(dataset: dataset)
        #expect(!options.hasCoordinates && !options.hasMatrices && options.defaultSpec == nil)
        #expect(DistanceAnalysis(spec: DistanceSpec(), dataset: dataset) == nil)
    }

    // MARK: - Storage

    @Test func specsRoundTripAsJSON() throws {
        let spec = DistanceSpec(level: "Population")
        #expect(spec.json == #"{"level":"Population","measure":"great_circle","units":"km"}"#)
        #expect(DistanceSpec(json: spec.json) == spec)
        #expect(DistanceSpec(json: nil) == nil && DistanceSpec(json: #"{"kind":"pca"}"#) == nil)
    }

    @Test func matricesExportAsCSVThatRReads() throws {
        let arapat = try ExampleDataset.arapatPopulations.load()
        let result = try run("Population", arapat)
        let lines = result.heatmapData.csvText.split(separator: "\n")
        #expect(lines.count == 40 && lines[0].hasPrefix(",88,9,84,"))
        #expect(lines[1].hasPrefix("88,0,"))
        let file = result.heatmapData.csvFile(named: "Great-circle distance among Population")
        #expect(file.suggestedName == "Great-circle distance among Population.csv")
    }

    @Test func storedMatricesKeepTheirSpecThroughAFile() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).gstudio")
        defer { try? FileManager.default.removeItem(at: url) }
        let fst = Matrix(nested: [[0, 0.2], [0.2, 0]], rowNames: ["A", "B"], colNames: ["A", "B"])
        let stored = MatrixAttachment(name: "Fst from R", data: try JSONEncoder().encode(fst), spec: #"{"from":"R"}"#)
        try await ProjectStore.saveSnapshot(matrices: [stored], projectName: "matrices", to: url)
        let snapshot = try await ProjectStore.loadSnapshot(from: url)
        #expect(snapshot.matrices == [stored])
        #expect(try snapshot.matrices[0].csvText() == ",A,B\nA,0,0.2\nB,0.2,0\n")
    }

    @Test func versionOneMatrixTablesStillRead() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).gstudio")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ProjectStore()
        try await store.create(at: url, components: [.matrices], projectName: "old")
        try await store.addMatrix(Data("{}".utf8), name: "old matrix")
        await store.close()
        // Make it a version 1 file: no spec column.
        let connection = SQLiteConnection()
        try connection.open(at: url, mode: .readWrite)
        try connection.execute("ALTER TABLE matrices DROP COLUMN spec")
        try connection.execute("UPDATE meta SET value = '1' WHERE key = 'matrices_schema_version'")
        connection.close()

        let reader = ProjectStore()
        try await reader.open(at: url, mode: .readOnly)
        #expect(try await reader.matrices().map(\.name) == ["old matrix"])
        #expect(try await reader.matrices().first?.spec == nil)
        await reader.close()

        let writer = ProjectStore()
        try await writer.open(at: url, mode: .readWrite)
        try await writer.addMatrix(Data("{}".utf8), name: "new matrix", spec: DistanceSpec().json)
        #expect(try await writer.matrices().map(\.spec) == [nil, DistanceSpec().json])
        await writer.close()
        let check = SQLiteConnection()
        try check.open(at: url, mode: .readOnly)
        #expect(try MatricesSchemaComponent.validateSchemaVersion(of: check) == 2)
        check.close()
    }
}
