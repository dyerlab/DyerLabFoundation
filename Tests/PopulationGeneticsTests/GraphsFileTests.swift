//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GraphsFileTests.swift
//  PopulationGeneticsTests
//
//  Exercises `.graphs` files: creating one, reading it back, and saving node
//  attributes without disturbing other components or another program's edits.
//
//  Created by Rodney Dyer on 2026.11.05.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Graph
import Testing
@testable import PopulationGenetics

struct GraphsFileTests {

    private let graph = try! Graph.importPGraph(text: "3\t2\nA\t1\t1\nB\t2\t2\nC\t3\t2\nA\tB\t1.5\nB\tC\t2.5\n")

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".graphs")
    }

    private func makeFile(references: [String] = ["rs123", "chr2_884A"]) async throws -> URL {
        let url = temporaryURL()
        let dataset = PopulationGraphDataset(attributesOf: GraphSnapshot(graph))
        try await GraphsFile.create(GraphsFileContents(projectName: "lopho", graph: dataset,
                                                       locusReferences: references), at: url)
        return url
    }

    private func update(_ attributes: Set<String>, nodes: (GraphSnapshot.NodeRecord) -> GraphSnapshot.NodeRecord,
                        in url: URL) async throws {
        var snapshot = try await GraphsFile.read(from: url).graph.graph
        snapshot.nodes = snapshot.nodes.map(nodes)
        try await GraphsFile.update(url, applying: GraphNodeAttributeUpdate(attributes: attributes, from: snapshot),
                                    to: url)
    }

    @Test func createsTheFiveComponentsWithoutGeneticData() async throws {
        let url = try await makeFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ProjectStore()
        try await store.open(at: url, mode: .readOnly)
        let present = await store.presentComponents
        await store.close()
        #expect(present.contains(GraphsFile.components))
        #expect(!present.contains(.geneticData))
    }

    @Test func readsTheGraphReferencesAndAttributesBack() async throws {
        let url = try await makeFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let contents = try await GraphsFile.read(from: url)
        #expect(contents.projectName == "lopho")
        #expect(contents.locusReferences == ["rs123", "chr2_884A"])
        #expect(contents.graph.graph.edges.count == graph.edges.count)
        // `group` was a text attribute on the original nodes.
        let live = contents.graph.makeGraphWithAttributes()
        #expect(live.nodes.first { $0.name == "B" }?.categoricalAttributes["group"] == "2")
    }

    @Test func dataHoldsAReadableFile() async throws {
        let url = try await makeFile()
        let copy = temporaryURL()
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: copy)
        }
        let contents = try await GraphsFile.read(from: url)
        try await GraphsFile.data(for: contents).write(to: copy)
        #expect(try await GraphsFile.read(from: copy).locusReferences == contents.locusReferences)
    }

    @Test func aFileWithNoGraphIsRejected() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ProjectStore()
        try await store.create(at: url, components: [.log], projectName: "log only")
        await store.close()
        await #expect(throws: GraphsFileError.noGraph) { try await GraphsFile.read(from: url) }
    }

    @Test func updateKeepsOtherComponentsAndReferences() async throws {
        let url = try await makeFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ProjectStore()
        try await store.open(at: url)
        try await store.addMatrix(Data([1, 2, 3]), name: "distances", description: nil)
        try await store.setMetadata("kept", forKey: "r.note")
        await store.close()

        try await update(["Elevation"], nodes: { node in
            var node = node
            node.continuousAttributes["Elevation"] = 12.5
            return node
        }, in: url)

        let reopened = ProjectStore()
        try await reopened.open(at: url, mode: .readOnly)
        let matrices = try await reopened.matrices().map(\.name)
        let note = try await reopened.metadata(forKey: "r.note")
        let references = try await reopened.graphLocusReferences()
        let values = try await reopened.readGraph().nodeValues.values.joined().filter { $0.name == "Elevation" }
        await reopened.close()
        #expect(matrices == ["distances"])
        #expect(note == "kept")
        #expect(references == ["rs123", "chr2_884A"])
        #expect(values.count == 3)
    }

    @Test func updateStartsFromWhatIsOnDiskNow() async throws {
        let url = try await makeFile()
        defer { try? FileManager.default.removeItem(at: url) }

        // The viewer captures its update, then another program edits the file.
        var snapshot = try await GraphsFile.read(from: url).graph.graph
        snapshot.nodes[0].categoricalAttributes["Habitat"] = "Desert"
        let pending = GraphNodeAttributeUpdate(attributes: ["Habitat"], from: snapshot)

        let store = ProjectStore()
        try await store.open(at: url)
        var other = try await store.readGraph()
        other = PopulationGraphDataset(graph: other.graph, nodeStrata: other.nodeStrata,
                                       nodeValues: other.nodeValues, edgeValues: other.edgeValues,
                                       graphValues: ["diameter": 7], loci: other.loci)
        try await store.writeGraph(other.graph, nodeStrata: other.nodeStrata, nodeValues: other.nodeValues,
                                   edgeValues: other.edgeValues, graphValues: other.graphValues)
        await store.close()

        try await GraphsFile.update(url, applying: pending, to: url)

        let saved = try await GraphsFile.read(from: url).graph
        #expect(saved.graphValues["diameter"] == 7)
        #expect(saved.makeGraphWithAttributes().nodes[0].categoricalAttributes["Habitat"] == "Desert")
    }

    @Test func reimportChangesAnAttributesType() async throws {
        let url = try await makeFile()
        defer { try? FileManager.default.removeItem(at: url) }

        try await update(["v"], nodes: { node in
            var node = node
            node.continuousAttributes["v"] = 1.5
            return node
        }, in: url)
        try await update(["v"], nodes: { node in
            var node = node
            node.continuousAttributes["v"] = nil
            node.categoricalAttributes["v"] = "high"
            return node
        }, in: url)

        let node = try await GraphsFile.read(from: url).graph.makeGraphWithAttributes().nodes[0]
        #expect(node.continuousAttributes["v"] == nil)
        #expect(node.categoricalAttributes["v"] == "high")
    }

    @Test func updateRefusesAGraphWhoseNodesChanged() async throws {
        let url = try await makeFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let before = try Data(contentsOf: url)

        var snapshot = try await GraphsFile.read(from: url).graph.graph
        snapshot.nodes[0].name = "Renamed"
        snapshot.nodes[0].continuousAttributes["x"] = 1
        let pending = GraphNodeAttributeUpdate(attributes: ["x"], from: snapshot)

        await #expect(throws: GraphsFileError.nodesChanged) {
            try await GraphsFile.update(url, applying: pending, to: url)
        }
        #expect(try Data(contentsOf: url) == before)
    }

    @Test func updatingToANewDestinationLeavesTheSourceAlone() async throws {
        let url = try await makeFile()
        let copy = temporaryURL()
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: copy)
        }
        let before = try Data(contentsOf: url)
        let snapshot = try await GraphsFile.read(from: url).graph.graph
        try await GraphsFile.update(url, applying: GraphNodeAttributeUpdate(attributes: [], from: snapshot), to: copy)
        #expect(try Data(contentsOf: url) == before)
        #expect(try await GraphsFile.read(from: copy).projectName == "lopho")
    }

    @Test func emptyReferencesRemoveTheRecord() async throws {
        let url = try await makeFile(references: [])
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ProjectStore()
        try await store.open(at: url, mode: .readOnly)
        let stored = try await store.metadata(forKey: ProjectStore.MetadataKey.graphLocusReferences)
        await store.close()
        #expect(stored == nil)
    }
}
