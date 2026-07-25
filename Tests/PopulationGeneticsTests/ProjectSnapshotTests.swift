//
//  ProjectSnapshotTests.swift
//  PopulationGenetics
//
//  Round-trip and atomicity coverage for saveSnapshot/loadSnapshot — the
//  "persist everything currently held, in one call" pair that generalizes
//  save(_:...)/load(from:) to all five StoreComponents.
//

import CoreLocation
import Foundation
import Graph
import Matrix
import PresentationZen
import SwiftUI
import Testing
@testable import PopulationGenetics

struct ProjectSnapshotTests {

    private func makeMatrix() -> GenotypeMatrix {
        let individuals = [Individual(name: "i0"), Individual(name: "i1")]
        let snpBook = AlleleCodebook(alleles: ["G", "A"])
        let snp = BiallelicColumn(codebook: snpBook, codes: [1, 2])
        let loci = [Locus(name: "snp1", location: 100, contig: "1")]
        return GenotypeMatrix(individuals: individuals, loci: loci, columns: [snp])
    }

    private func makeGraph() -> Graph {
        let g = Graph()
        g.addNode(name: "A", size: 1.0, color: .red)
        g.addNode(name: "B", size: 2.0, color: .blue)
        g.addEdge(from: "A", to: "B", weight: 1.0, symmetric: false)
        return g
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".db")
    }

    @Test func saveSnapshotThenLoadSnapshotRoundTripsAllFiveComponents() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let matrix = makeMatrix()
        let dataset = ImportedDataset(matrix: matrix, parentage: ParentageDesign(families: []))
        let graphDataset = PopulationGraphDataset(graph: makeGraph(), loci: matrix.loci)
        let result = AnalysisResult(name: "AMOVA", body: "# AMOVA")
        let logEntry = LogEntry(logType: .fileIO, message: "Loaded bundled sample dataset")
        let fst = Matrix(nested: [[1.0, 0.5], [0.5, 1.0]], rowNames: ["popA", "popB"], colNames: ["popA", "popB"])
        let attachment = MatrixAttachment(name: "Fst distances", description: "Pairwise Fst",
                                           data: try JSONEncoder().encode(fst))

        try await ProjectStore.saveSnapshot(dataset: dataset, graph: graphDataset, results: [result],
                                             logEntries: [logEntry], matrices: [attachment],
                                             projectName: "test-project", species: "Araptus attenuatus",
                                             description: "A test project", to: url)

        let snapshot = try await ProjectStore.loadSnapshot(from: url)

        #expect(snapshot.projectName == "test-project")
        #expect(snapshot.species == "Araptus attenuatus")
        #expect(snapshot.description == "A test project")
        #expect(snapshot.dataset?.matrix.individualCount == 2)
        #expect(snapshot.graph?.graph.nodes.count == 2)
        #expect(snapshot.graph?.loci.map(\.name) == ["snp1"])
        #expect(snapshot.results.map(\.id) == [result.id])
        #expect(snapshot.logEntries.map(\.id) == [logEntry.id])
        #expect(snapshot.matrices.map(\.name) == ["Fst distances"])
        let decoded = try JSONDecoder().decode(Matrix.self, from: snapshot.matrices[0].data)
        #expect(decoded == fst)
    }

    @Test func saveSnapshotOmitsComponentsForNilOrEmptyArguments() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let dataset = ImportedDataset(matrix: makeMatrix(), parentage: ParentageDesign(families: []))
        try await ProjectStore.saveSnapshot(dataset: dataset, projectName: "genetic-data-only", to: url)

        let snapshot = try await ProjectStore.loadSnapshot(from: url)
        #expect(snapshot.dataset != nil)
        #expect(snapshot.graph == nil)
        #expect(snapshot.results.isEmpty)
        #expect(snapshot.logEntries.isEmpty)
        #expect(snapshot.matrices.isEmpty)
    }

    @Test func saveSnapshotOverwritesExistingFileFromScratch() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let first = ImportedDataset(matrix: makeMatrix(), parentage: ParentageDesign(families: []))
        try await ProjectStore.saveSnapshot(dataset: first, results: [AnalysisResult(name: "old", body: "old")],
                                             projectName: "v1", to: url)

        // Second save omits results entirely — a from-scratch rewrite means they're
        // gone, not merged with the prior save's contents.
        let secondMatrix = GenotypeMatrix(
            individuals: [Individual(name: "i0"), Individual(name: "i1"), Individual(name: "i2")],
            loci: [Locus(name: "snp1", location: 100, contig: "1")],
            columns: [BiallelicColumn(codebook: AlleleCodebook(alleles: ["G", "A"]), codes: [1, 2, 3])])
        let second = ImportedDataset(matrix: secondMatrix, parentage: ParentageDesign(families: []))
        try await ProjectStore.saveSnapshot(dataset: second, projectName: "v2", to: url)

        let snapshot = try await ProjectStore.loadSnapshot(from: url)
        #expect(snapshot.projectName == "v2")
        #expect(snapshot.dataset?.matrix.individualCount == 3)
        #expect(snapshot.results.isEmpty)
    }

    @Test func saveSnapshotLeavesOriginalFileUntouchedIfAWriteFails() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let good = ImportedDataset(matrix: makeMatrix(), parentage: ParentageDesign(families: []))
        try await ProjectStore.saveSnapshot(dataset: good, projectName: "original", to: url)

        let strangerLocus = Locus(name: "not-in-file")
        let brokenGraph = PopulationGraphDataset(graph: makeGraph(), loci: [strangerLocus])

        await #expect(throws: PersistenceError.self) {
            try await ProjectStore.saveSnapshot(dataset: good, graph: brokenGraph, projectName: "should-not-land",
                                                 to: url)
        }

        // The original file must be completely untouched by the failed attempt.
        let snapshot = try await ProjectStore.loadSnapshot(from: url)
        #expect(snapshot.projectName == "original")
        #expect(snapshot.graph == nil)

        // No leftover temp file beside it either.
        let siblingFiles = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
        #expect(!siblingFiles.contains(where: { $0.hasPrefix(".\(url.lastPathComponent).") }))
    }

    @Test func saveSnapshotCreatesBrandNewFile() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(!FileManager.default.fileExists(atPath: url.path))

        let dataset = ImportedDataset(matrix: makeMatrix(), parentage: ParentageDesign(families: []))
        try await ProjectStore.saveSnapshot(dataset: dataset, projectName: "brand-new", to: url)

        #expect(FileManager.default.fileExists(atPath: url.path))
        let snapshot = try await ProjectStore.loadSnapshot(from: url)
        #expect(snapshot.projectName == "brand-new")
    }
}
