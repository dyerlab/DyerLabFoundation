//
//  PopulationGraphSQLiteTests.swift
//  PopulationGenetics
//
//  Round-trip tests for the population graph and results/images tables
//  layered onto a GenotypeMatrixStore file.
//

import CoreLocation
import Foundation
import Graph
import PresentationZen
import SwiftUI
import Testing
@testable import PopulationGenetics

struct PopulationGraphSQLiteTests {

    private func makeMatrix() -> GenotypeMatrix {
        let individuals = [Individual(name: "i0"), Individual(name: "i1")]
        let snpBook = AlleleCodebook(alleles: ["G", "A"])
        let snp = BiallelicColumn(codebook: snpBook, codes: [1, 2])
        let loci = [Locus(name: "snp1", location: 100, contig: "1")]
        return GenotypeMatrix(individuals: individuals, loci: loci, columns: [snp])
    }

    private func makeGraph() -> Graph {
        let g = Graph()
        g.addNode(name: "A", size: 1.0, color: .red, coordinate: CLLocationCoordinate2D(latitude: 37.5, longitude: -77.4))
        g.addNode(name: "B", size: 2.0, color: .blue)
        g.addNode(name: "C", size: 3.0, color: .green)
        g.addEdge(from: "A", to: "B", weight: 4.2, symmetric: false)
        g.addEdge(from: "B", to: "C", weight: 1.7, symmetric: false)
        return g
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".db")
    }

    // MARK: - Graph round trip

    @Test func roundTripPreservesNodesAndEdges() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = GenotypeMatrixStore()
        try await store.create(at: url, overwrite: true)
        try await store.write(matrix: makeMatrix(), projectName: "test-project")

        let original = makeGraph()
        try await store.writeGraph(original)
        await store.close()

        let reader = GenotypeMatrixStore()
        try await reader.open(at: url, mode: .readOnly)
        let dataset = try await reader.readGraph()
        await reader.close()

        #expect(dataset.graph.nodes.count == original.nodes.count)
        #expect(dataset.graph.edges.count == original.edges.count)

        for node in original.nodes {
            let reloaded = dataset.graph.node(id: node.id)
            #expect(reloaded != nil)
            #expect(reloaded?.name == node.name)
            #expect(reloaded?.size == node.size)
            #expect(reloaded?.coordinate?.latitude == node.coordinate?.latitude)
            #expect(reloaded?.coordinate?.longitude == node.coordinate?.longitude)
        }

        for edge in original.edges {
            let reloaded = dataset.graph.edges.first(where: { $0.id == edge.id })
            #expect(reloaded != nil)
            #expect(reloaded?.fromNode == edge.fromNode)
            #expect(reloaded?.toNode == edge.toNode)
            #expect(reloaded?.weight == edge.weight)
        }
    }

    @Test func roundTripPreservesNodeStrataNodeValuesEdgeValuesAndGraphValues() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = GenotypeMatrixStore()
        try await store.create(at: url, overwrite: true)
        try await store.write(matrix: makeMatrix(), projectName: "test-project")

        let graph = makeGraph()
        let nodeA = graph.nodes[0]
        let nodeB = graph.nodes[1]
        let edgeAB = graph.edges[0]

        let populationRef = StratumReference(level: "Population", name: "SBP")
        let regionRef = StratumReference(level: "Region", name: "North")

        try await store.writeGraph(
            graph,
            nodeStrata: [nodeA.id: [populationRef, regionRef]],
            nodeValues: [nodeA.id: [GraphValue(name: "elevation", value: 812.5, kind: .extrinsic)]],
            edgeValues: [edgeAB.id: [GraphValue(name: "bootstrap_support", value: 0.94, kind: .intrinsic)]],
            graphValues: ["diameter": 2.0, "component_count": 1.0]
        )
        await store.close()

        let reader = GenotypeMatrixStore()
        try await reader.open(at: url, mode: .readOnly)
        let dataset = try await reader.readGraph()
        await reader.close()

        let reloadedStrata = dataset.nodeStrata[nodeA.id] ?? []
        #expect(Set(reloadedStrata.map(\.name)) == Set(["SBP", "North"]))
        #expect(reloadedStrata.first(where: { $0.name == "SBP" })?.level == "Population")

        #expect(dataset.nodeValues[nodeA.id]?.first?.name == "elevation")
        #expect(dataset.nodeValues[nodeA.id]?.first?.value == 812.5)
        #expect(dataset.nodeValues[nodeA.id]?.first?.kind == .extrinsic)
        #expect(dataset.nodeValues[nodeB.id] == nil)

        let reloadedEdgeAB = dataset.graph.edges.first(where: { $0.id == edgeAB.id })!
        #expect(dataset.edgeValues[reloadedEdgeAB.id]?.first?.name == "bootstrap_support")
        #expect(dataset.edgeValues[reloadedEdgeAB.id]?.first?.kind == .intrinsic)

        #expect(dataset.graphValues["diameter"] == 2.0)
        #expect(dataset.graphValues["component_count"] == 1.0)
    }

    @Test func roundTripPreservesGraphLociProvenance() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let matrix = makeMatrix()
        let store = GenotypeMatrixStore()
        try await store.create(at: url, overwrite: true)
        try await store.write(matrix: matrix, projectName: "test-project")
        try await store.writeGraph(makeGraph(), loci: matrix.loci)
        await store.close()

        let reader = GenotypeMatrixStore()
        try await reader.open(at: url, mode: .readOnly)
        let dataset = try await reader.readGraph()
        await reader.close()

        #expect(dataset.loci.count == 1)
        #expect(dataset.loci.first?.name == "snp1")
        #expect(dataset.loci.first?.id == matrix.loci.first?.id)
    }

    @Test func writeGraphRejectsLocusNotInFile() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = GenotypeMatrixStore()
        try await store.create(at: url, overwrite: true)
        try await store.write(matrix: makeMatrix(), projectName: "test-project")

        let strangerLocus = Locus(name: "not-in-file")
        await #expect(throws: PersistenceError.self) {
            try await store.writeGraph(makeGraph(), loci: [strangerLocus])
        }
    }

    // MARK: - Results / images

    @Test func roundTripPreservesResultsInInsertionOrder() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = GenotypeMatrixStore()
        try await store.create(at: url, overwrite: true)

        let first = AnalysisResult(name: "AMOVA", description: "Permutation test", body: "# AMOVA\n\nΦ = 0.14")
        let second = AnalysisResult(name: "Rarefaction", body: "# Rarefaction curve")
        try await store.addResult(first)
        try await store.addResult(second)

        let results = try await store.results()
        #expect(results.map(\.id) == [first.id, second.id])
        #expect(results[0].name == "AMOVA")
        #expect(results[0].description == "Permutation test")
        #expect(results[0].body == "# AMOVA\n\nΦ = 0.14")
        #expect(results[1].description == nil)

        let fetched = try await store.result(id: first.id)
        #expect(fetched?.body == first.body)
    }

    @Test func roundTripPreservesAttachedImage() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = GenotypeMatrixStore()
        try await store.create(at: url, overwrite: true)

        let result = AnalysisResult(name: "AMOVA", body: "![Null distribution](attachment:null_distribution)")
        try await store.addResult(result)

        let bytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let image = ResultImage(name: "null_distribution", mimeType: "image/png", width: 640, height: 480, data: bytes)
        try await store.attachImage(image, to: result.id)

        let reloaded = try await store.image(named: "null_distribution", for: result.id)
        #expect(reloaded?.data == bytes)
        #expect(reloaded?.mimeType == "image/png")
        #expect(reloaded?.width == 640)
        #expect(reloaded?.height == 480)

        let missing = try await store.image(named: "does_not_exist", for: result.id)
        #expect(missing == nil)
    }

    @Test func openReadOnlyRejectsGraphAndResultWrites() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = GenotypeMatrixStore()
        try await store.create(at: url, overwrite: true)
        try await store.write(matrix: makeMatrix(), projectName: "test-project")
        await store.close()

        let reader = GenotypeMatrixStore()
        try await reader.open(at: url, mode: .readOnly)

        await #expect(throws: PersistenceError.readOnly) {
            try await reader.writeGraph(makeGraph())
        }
        await #expect(throws: PersistenceError.readOnly) {
            try await reader.addResult(AnalysisResult(name: "x", body: "y"))
        }
        await reader.close()
    }
}
