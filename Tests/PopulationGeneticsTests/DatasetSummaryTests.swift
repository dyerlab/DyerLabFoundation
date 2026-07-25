//
//  DatasetSummaryTests.swift
//  PopulationGenetics
//
//  Exercises DatasetSummary — the cheap meta-table classification read by
//  ProjectStore.readSummary(), used e.g. by an "Open Recent" file picker to
//  choose an icon without decoding the full dataset.
//

import CoreLocation
import Foundation
import Graph
import PresentationZen
import SwiftUI
import Testing
@testable import PopulationGenetics

struct DatasetSummaryTests {

    private func makeSNPMatrix() -> GenotypeMatrix {
        let individuals = [Individual(name: "i0"), Individual(name: "i1")]
        let snpBook = AlleleCodebook(alleles: ["G", "A"])
        let snp = BiallelicColumn(codebook: snpBook, codes: [1, 2])
        let loci = [Locus(name: "snp1", location: 100, contig: "1")]
        return GenotypeMatrix(individuals: individuals, loci: loci, columns: [snp])
    }

    private func makeMicrosatMatrix() -> GenotypeMatrix {
        let individuals = [Individual(name: "i0"), Individual(name: "i1")]
        let msatBook = AlleleCodebook(alleles: ["128", "130"])
        let msat = MultiallelicColumn(codebook: msatBook, left: [1, 2], right: [2, 2])
        let loci = [Locus(name: "MP20", location: 0, contig: "1")]
        return GenotypeMatrix(individuals: individuals, loci: loci, columns: [msat])
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".db")
    }

    @Test func freshWriteReportsSNPCompositionAndNoParentageGraphOrResults() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ProjectStore()
        try await store.create(at: url, overwrite: true, projectName: "test-project", species: "Araptus attenuatus",
                                description: "A study of cactus-associated weevils across the Sonoran Desert.")
        try await store.writeGeneticData(matrix: makeSNPMatrix())
        await store.close()

        let reader = ProjectStore()
        try await reader.open(at: url, mode: .readOnly)
        let summary = try await reader.readSummary()
        await reader.close()

        #expect(summary.projectName == "test-project")
        #expect(summary.species == "Araptus attenuatus")
        #expect(summary.description == "A study of cactus-associated weevils across the Sonoran Desert.")
        #expect(summary.individualCount == 2)
        #expect(summary.locusCount == 1)
        #expect(summary.markerComposition == .snp)
        #expect(summary.hasParentage == false)
        #expect(summary.hasGraph == false)
        #expect(summary.hasResults == false)
        #expect(summary.hasLog == false)
        #expect(summary.hasMatrices == false)
    }

    @Test func omittedDescriptionReadsBackAsNil() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ProjectStore()
        try await store.create(at: url, overwrite: true, projectName: "test-project")
        try await store.writeGeneticData(matrix: makeSNPMatrix())
        await store.close()

        let reader = ProjectStore()
        try await reader.open(at: url, mode: .readOnly)
        let summary = try await reader.readSummary()
        await reader.close()

        #expect(summary.description == nil)
    }

    @Test func microsatelliteMatrixReportsMicrosatelliteComposition() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ProjectStore()
        try await store.create(at: url, overwrite: true, projectName: "test-project")
        try await store.writeGeneticData(matrix: makeMicrosatMatrix())
        await store.close()

        let reader = ProjectStore()
        try await reader.open(at: url, mode: .readOnly)
        let summary = try await reader.readSummary()
        await reader.close()

        #expect(summary.markerComposition == .microsatellite)
    }

    @Test func parentageDesignWithFamiliesFlipsHasParentage() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let matrix = makeMicrosatMatrix()
        let parentage = ParentageDesign(families: [MaternalFamily(id: "fam1", mother: 0, offspring: [1])])

        let store = ProjectStore()
        try await store.create(at: url, overwrite: true, projectName: "test-project")
        try await store.writeGeneticData(matrix: matrix, parentage: parentage)
        await store.close()

        let reader = ProjectStore()
        try await reader.open(at: url, mode: .readOnly)
        let summary = try await reader.readSummary()
        await reader.close()

        #expect(summary.hasParentage == true)
    }

    @Test func writingGraphFlipsHasGraph() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ProjectStore()
        try await store.create(at: url, overwrite: true, projectName: "test-project")
        try await store.writeGeneticData(matrix: makeSNPMatrix())

        let graph = Graph()
        graph.addNode(name: "A", size: 1.0, color: .red, coordinate: CLLocationCoordinate2D(latitude: 37.5, longitude: -77.4))
        graph.addNode(name: "B", size: 2.0, color: .blue)
        graph.addEdge(from: "A", to: "B", weight: 1.0, symmetric: false)
        try await store.writeGraph(graph)
        await store.close()

        let reader = ProjectStore()
        try await reader.open(at: url, mode: .readOnly)
        let summary = try await reader.readSummary()
        await reader.close()

        #expect(summary.hasGraph == true)
    }

    @Test func addingResultFlipsHasResults() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ProjectStore()
        try await store.create(at: url, overwrite: true, projectName: "test-project")
        try await store.writeGeneticData(matrix: makeSNPMatrix())
        try await store.addResult(AnalysisResult(name: "AMOVA", body: "# AMOVA"))
        await store.close()

        let reader = ProjectStore()
        try await reader.open(at: url, mode: .readOnly)
        let summary = try await reader.readSummary()
        await reader.close()

        #expect(summary.hasResults == true)
    }

    @Test func appendingLogEntryFlipsHasLog() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ProjectStore()
        try await store.create(at: url, overwrite: true, projectName: "test-project")
        try await store.writeGeneticData(matrix: makeSNPMatrix())
        try await store.appendLog(LogEntry(logType: .fileIO, message: "Imported test-project.csv"))
        await store.close()

        let reader = ProjectStore()
        try await reader.open(at: url, mode: .readOnly)
        let summary = try await reader.readSummary()
        await reader.close()

        #expect(summary.hasLog == true)
    }

    // MARK: - Component presence vs. absence

    @Test func partialComponentsReadAsNilNotFalse() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ProjectStore()
        try await store.create(at: url, overwrite: true, components: .log, projectName: "log-only-project")
        try await store.appendLog(LogEntry(logType: .fileIO, message: "started"))
        await store.close()

        let reader = ProjectStore()
        try await reader.open(at: url, mode: .readOnly)
        let summary = try await reader.readSummary()
        await reader.close()

        #expect(summary.projectName == "log-only-project")
        #expect(summary.hasLog == true)
        #expect(summary.individualCount == nil)
        #expect(summary.locusCount == nil)
        #expect(summary.markerComposition == nil)
        #expect(summary.hasParentage == nil)
        #expect(summary.hasGraph == nil)
        #expect(summary.hasResults == nil)
        #expect(summary.hasMatrices == nil)
    }

    @Test func readingAnAbsentComponentThrowsComponentNotPresent() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ProjectStore()
        try await store.create(at: url, overwrite: true, components: .log, projectName: "log-only-project")
        await store.close()

        let reader = ProjectStore()
        try await reader.open(at: url, mode: .readOnly)

        await #expect(throws: PersistenceError.componentNotPresent("graph")) {
            _ = try await reader.readGraph()
        }
        await #expect(throws: PersistenceError.componentNotPresent("results")) {
            _ = try await reader.results()
        }
        await #expect(throws: PersistenceError.componentNotPresent("geneticData")) {
            _ = try await reader.readGeneticData()
        }
        await #expect(throws: PersistenceError.componentNotPresent("matrices")) {
            _ = try await reader.matrices()
        }
        await reader.close()
    }
}
