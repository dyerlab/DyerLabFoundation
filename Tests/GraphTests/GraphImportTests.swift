//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Testing
import SwiftUI
import Foundation
@testable import Graph

struct GraphImportTests {

    // MARK: - .pgraph

    @Test func pgraphParsesNodesAndSymmetricEdges() async throws {
        let text = """
        3	2
        A	1.0	1
        B	2.0	1
        C	3.0	2
        A	B	1.5
        B	C	2.5
        """
        let g = try Graph.importPGraph(text: text)
        #expect(g.cardinality == 3)
        #expect(g.edges.count == 4, "each of the 2 edges should be added symmetrically")
        #expect(g.node(name: "A")?.size == 1.0)
        #expect(g.node(name: "A")?.categoricalAttributes["group"] == "1")
        #expect(g.node(name: "C")?.categoricalAttributes["group"] == "2")
        #expect(g.shortestPath(from: "A", to: "C")?.distance == 4.0)
    }

    @Test func pgraphColorsAreDeterministicByGroup() async throws {
        let text = """
        3	0
        A	1.0	1
        B	2.0	2
        C	3.0	1
        """
        let g = try Graph.importPGraph(text: text)
        #expect(g.node(name: "A")?.color == g.node(name: "C")?.color, "same group should get the same color")
        #expect(g.node(name: "A")?.color != g.node(name: "B")?.color, "different groups should get different colors")
    }

    @Test func pgraphRejectsMalformedHeader() async throws {
        #expect(throws: GraphImportError.self) {
            _ = try Graph.importPGraph(text: "not a header\n")
        }
    }

    @Test func pgraphRejectsUnknownEdgeNode() async throws {
        let text = """
        1	1
        A	1.0	1
        A	B	1.0
        """
        #expect(throws: GraphImportError.self) {
            _ = try Graph.importPGraph(text: text)
        }
    }

    // MARK: - GeoJSON

    @Test func geoJSONParsesNodesAndSymmetricEdges() async throws {
        let json = """
        {
            "type": "FeatureCollection",
            "features": [
                { "type": "Feature", "geometry": { "type": "Point", "coordinates": [0, 0] },
                  "properties": { "name": "A", "size": 1.0, "color": "#FF0000", "Region": "north" } },
                { "type": "Feature", "geometry": { "type": "Point", "coordinates": [1, 1] },
                  "properties": { "name": "B", "size": 2.0, "color": "#0000FF" } },
                { "type": "Feature", "geometry": { "type": "LineString", "coordinates": [[0, 0], [1, 1]] },
                  "properties": { "weight": 3.5 } }
            ]
        }
        """
        let g = try Graph.importGeoJSON(data: Data(json.utf8))
        #expect(g.cardinality == 2)
        #expect(g.edges.count == 2, "the edge should be added symmetrically")
        #expect(g.node(name: "A")?.categoricalAttributes["Region"] == "north")
        #expect(g.node(name: "A")?.color == Color(red: 1, green: 0, blue: 0))
        #expect(g.shortestPath(from: "A", to: "B")?.distance == 3.5)
    }

    @Test func geoJSONRejectsMissingNodeName() async throws {
        let json = """
        { "type": "FeatureCollection", "features": [
            { "type": "Feature", "geometry": { "type": "Point", "coordinates": [0, 0] },
              "properties": { "size": 1.0 } }
        ] }
        """
        #expect(throws: GraphImportError.self) {
            _ = try Graph.importGeoJSON(data: Data(json.utf8))
        }
    }

    @Test func geoJSONRejectsUnresolvedEdgeEndpoint() async throws {
        let json = """
        { "type": "FeatureCollection", "features": [
            { "type": "Feature", "geometry": { "type": "Point", "coordinates": [0, 0] },
              "properties": { "name": "A", "size": 1.0 } },
            { "type": "Feature", "geometry": { "type": "LineString", "coordinates": [[0, 0], [9, 9]] },
              "properties": { "weight": 1.0 } }
        ] }
        """
        #expect(throws: GraphImportError.self) {
            _ = try Graph.importGeoJSON(data: Data(json.utf8))
        }
    }

    // MARK: - Bundled lopho data stays in sync across formats

    @Test func bundledLophoFormatsAgree() async throws {
        let pgraphURL = try GraphExampleData.url("lopho", extension: "pgraph")
        let geoJSONURL = try GraphExampleData.url("lopho", extension: "geojson")

        let fromPGraph = try Graph.importPGraph(contentsOf: pgraphURL)
        let fromGeoJSON = try Graph.importGeoJSON(contentsOf: geoJSONURL)

        #expect(fromPGraph.cardinality == 21)
        #expect(fromGeoJSON.cardinality == 21)
        #expect(fromPGraph.edges.count == 100, "50 undirected edges, added symmetrically")
        #expect(fromGeoJSON.edges.count == 100)

        #expect(Set(fromPGraph.nodes.map(\.name)) == Set(fromGeoJSON.nodes.map(\.name)))

        for node in fromPGraph.nodes {
            let counterpart = try #require(fromGeoJSON.node(name: node.name))
            #expect(counterpart.size == node.size, "\(node.name) size should match across formats")
        }

        // .pgraph carries no real per-edge weight (every edge is a flat placeholder
        // "5"); only .geojson was synced to the authoritative genetic-distance
        // weights, so edge topology is compared here, not distances.
        let pgraphEdgeNames = Set(fromPGraph.edges.compactMap { edge -> Set<String>? in
            guard let pair = fromPGraph.nodesForEdge(edge) else { return nil }
            return Set(pair.map(\.name))
        })
        let geoJSONEdgeNames = Set(fromGeoJSON.edges.compactMap { edge -> Set<String>? in
            guard let pair = fromGeoJSON.nodesForEdge(edge) else { return nil }
            return Set(pair.map(\.name))
        })
        #expect(pgraphEdgeNames == geoJSONEdgeNames, "edge topology should match across formats")
    }

    @Test func lophoGraphMatchesBundledGeoJSON() async throws {
        let url = try GraphExampleData.url("lopho", extension: "geojson")
        let expected = try Graph.importGeoJSON(contentsOf: url)
        let actual = Graph.lophoGraph
        #expect(actual.cardinality == expected.cardinality)
        #expect(actual.edges.count == expected.edges.count)
    }
}
