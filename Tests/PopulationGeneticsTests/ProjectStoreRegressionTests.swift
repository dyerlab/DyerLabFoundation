//
//  ProjectStoreRegressionTests.swift
//  PopulationGenetics
//
//  Regression coverage for the bug that motivated splitting ProjectStore
//  into five independent components: writeGeneticData/writeGraph used to be
//  insert-only, so the only way to persist an edit was
//  create(overwrite:true) + write, which silently discarded whatever
//  graph/results/log/matrices data the file already held. Also covers the
//  new `.matrices` component (generic named `Matrix` attachments).
//

import CoreLocation
import Foundation
import Graph
import Matrix
import PresentationZen
import SwiftUI
import Testing
@testable import PopulationGenetics

struct ProjectStoreRegressionTests {

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

    /// The core regression test: editing genetic data and re-saving must not
    /// disturb the graph/results/log/matrices the file already held.
    @Test func editingGeneticDataAndResavingPreservesEveryOtherComponent() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ProjectStore()
        try await store.create(at: url, overwrite: true, projectName: "test-project")
        try await store.writeGeneticData(matrix: makeMatrix())
        try await store.writeGraph(makeGraph())
        let result = AnalysisResult(name: "AMOVA", body: "# AMOVA")
        try await store.addResult(result)
        let logEntry = LogEntry(logType: .fileIO, message: "Imported test-project.csv")
        try await store.appendLog(logEntry)
        let matrix = Matrix(nested: [[1.0, 0.5], [0.5, 1.0]], rowNames: ["popA", "popB"], colNames: ["popA", "popB"])
        try await store.addMatrix(try JSONEncoder().encode(matrix), name: "Fst distances")

        // Simulate an edit + re-save, exactly what a document's second save does.
        let edited = GenotypeMatrix(individuals: [Individual(name: "i0"), Individual(name: "i1"), Individual(name: "i2")],
                                     loci: [Locus(name: "snp1", location: 100, contig: "1")],
                                     columns: [BiallelicColumn(codebook: AlleleCodebook(alleles: ["G", "A"]),
                                                                codes: [1, 2, 3])])
        try await store.writeGeneticData(matrix: edited)
        await store.close()

        let reader = ProjectStore()
        try await reader.open(at: url, mode: .readOnly)

        let reloadedMatrix = try await reader.readGeneticData()
        #expect(reloadedMatrix.individualCount == 3)

        let reloadedGraph = try await reader.readGraph()
        #expect(reloadedGraph.graph.nodes.count == 2)
        #expect(reloadedGraph.graph.edges.count == 1)

        let reloadedResults = try await reader.results()
        #expect(reloadedResults.map(\.id) == [result.id])

        let reloadedLog = try await reader.logEntries()
        #expect(reloadedLog.map(\.id) == [logEntry.id])

        let reloadedMatrixInfos = try await reader.matrices()
        #expect(reloadedMatrixInfos.map(\.name) == ["Fst distances"])

        await reader.close()
    }

    @Test func addMatrixRoundTripsThroughJSONCodable() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let original = Matrix(nested: [[1.0, 0.2, 0.9], [0.2, 1.0, 0.4], [0.9, 0.4, 1.0]],
                               rowNames: ["popA", "popB", "popC"], colNames: ["popA", "popB", "popC"])

        let store = ProjectStore()
        try await store.create(at: url, overwrite: true, components: .matrices, projectName: "test-project")
        try await store.addMatrix(try JSONEncoder().encode(original), name: "Fst distances",
                                   description: "Pairwise Fst among three populations")
        await store.close()

        let reader = ProjectStore()
        try await reader.open(at: url, mode: .readOnly)
        let infos = try await reader.matrices()
        #expect(infos.count == 1)
        #expect(infos[0].name == "Fst distances")
        #expect(infos[0].description == "Pairwise Fst among three populations")

        let data = try #require(try await reader.matrixData(named: "Fst distances"))
        let decoded = try JSONDecoder().decode(Matrix.self, from: data)
        await reader.close()

        #expect(decoded == original)
    }

    @Test func addMatrixKeepsMostRecentUnderSameName() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ProjectStore()
        try await store.create(at: url, overwrite: true, components: .matrices, projectName: "test-project")
        let first = Matrix(nested: [[1.0]], rowNames: ["a"], colNames: ["a"])
        let second = Matrix(nested: [[2.0]], rowNames: ["b"], colNames: ["b"])
        try await store.addMatrix(try JSONEncoder().encode(first), name: "measure")
        try await store.addMatrix(try JSONEncoder().encode(second), name: "measure")
        await store.close()

        let reader = ProjectStore()
        try await reader.open(at: url, mode: .readOnly)
        let data = try #require(try await reader.matrixData(named: "measure"))
        let decoded = try JSONDecoder().decode(Matrix.self, from: data)
        await reader.close()

        #expect(decoded == second)
    }
}
