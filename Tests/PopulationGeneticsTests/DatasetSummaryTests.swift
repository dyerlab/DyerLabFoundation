//
//  DatasetSummaryTests.swift
//  PopulationGenetics
//
//  Exercises DatasetSummary — the cheap meta-table classification read by
//  GenotypeMatrixStore.readSummary(), used e.g. by an "Open Recent" file
//  picker to choose an icon without decoding the full dataset.
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

        let store = GenotypeMatrixStore()
        try await store.create(at: url, overwrite: true)
        try await store.write(matrix: makeSNPMatrix(), projectName: "test-project", species: "Araptus attenuatus")
        await store.close()

        let reader = GenotypeMatrixStore()
        try await reader.open(at: url, mode: .readOnly)
        let summary = try await reader.readSummary()
        await reader.close()

        #expect(summary.projectName == "test-project")
        #expect(summary.species == "Araptus attenuatus")
        #expect(summary.individualCount == 2)
        #expect(summary.locusCount == 1)
        #expect(summary.markerComposition == .snp)
        #expect(summary.hasParentage == false)
        #expect(summary.hasGraph == false)
        #expect(summary.hasResults == false)
    }

    @Test func microsatelliteMatrixReportsMicrosatelliteComposition() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = GenotypeMatrixStore()
        try await store.create(at: url, overwrite: true)
        try await store.write(matrix: makeMicrosatMatrix(), projectName: "test-project")
        await store.close()

        let reader = GenotypeMatrixStore()
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

        let store = GenotypeMatrixStore()
        try await store.create(at: url, overwrite: true)
        try await store.write(matrix: matrix, parentage: parentage, projectName: "test-project")
        await store.close()

        let reader = GenotypeMatrixStore()
        try await reader.open(at: url, mode: .readOnly)
        let summary = try await reader.readSummary()
        await reader.close()

        #expect(summary.hasParentage == true)
    }

    @Test func writingGraphFlipsHasGraph() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = GenotypeMatrixStore()
        try await store.create(at: url, overwrite: true)
        try await store.write(matrix: makeSNPMatrix(), projectName: "test-project")

        let graph = Graph()
        graph.addNode(name: "A", size: 1.0, color: .red, coordinate: CLLocationCoordinate2D(latitude: 37.5, longitude: -77.4))
        graph.addNode(name: "B", size: 2.0, color: .blue)
        graph.addEdge(from: "A", to: "B", weight: 1.0, symmetric: false)
        try await store.writeGraph(graph)
        await store.close()

        let reader = GenotypeMatrixStore()
        try await reader.open(at: url, mode: .readOnly)
        let summary = try await reader.readSummary()
        await reader.close()

        #expect(summary.hasGraph == true)
    }

    @Test func addingResultFlipsHasResults() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = GenotypeMatrixStore()
        try await store.create(at: url, overwrite: true)
        try await store.write(matrix: makeSNPMatrix(), projectName: "test-project")
        try await store.addResult(AnalysisResult(name: "AMOVA", body: "# AMOVA"))
        await store.close()

        let reader = GenotypeMatrixStore()
        try await reader.open(at: url, mode: .readOnly)
        let summary = try await reader.readSummary()
        await reader.close()

        #expect(summary.hasResults == true)
    }
}
