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
//  Test.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 5/21/25.
//

import SwiftUI
import Testing
@testable import Graph

struct GraphTests {

    @Test func graphConstruction() async throws {
        let G = Graph()

        #expect( G.cardinality == 0, "Failed cardinality" )
        #expect( G.node(name:"Bob") == nil, "Failed empty node access.")

        G.addNode(name: "Bob", size: 12.2, color: .red)
        #expect( G.cardinality == 1, "Failed cardinality, G=1" )
    }

    @Test func symmetricEdgeAddsBothDirections() async throws {
        let g = Graph()
        g.addNode(name: "A", size: 1.0, color: .red)
        g.addNode(name: "B", size: 1.0, color: .blue)

        g.addEdge(from: "A", to: "B", weight: 2.5, symmetric: true)

        // A symmetric edge creates both A→B and B→A.
        #expect(g.edges.count == 2)
        #expect(OutDegreeCentrality(graph: g) == [1.0, 1.0])
        #expect(InDegreeCentrality(graph: g) == [1.0, 1.0])
    }

    @Test func asymmetricEdgeAddsOneDirection() async throws {
        let g = Graph()
        g.addNode(name: "A", size: 1.0, color: .red)
        g.addNode(name: "B", size: 1.0, color: .blue)

        g.addEdge(from: "A", to: "B", weight: 2.5, symmetric: false)

        #expect(g.edges.count == 1)
        #expect(OutDegreeCentrality(graph: g) == [1.0, 0.0])
        #expect(InDegreeCentrality(graph: g) == [0.0, 1.0])
    }

    @Test func addEdgeWithMissingNodeIsNoOp() async throws {
        let g = Graph()
        g.addNode(name: "A", size: 1.0, color: .red)

        // Either endpoint missing → the edge is silently not added.
        g.addEdge(from: "A", to: "Ghost", weight: 1.0, symmetric: true)
        g.addEdge(from: "Ghost", to: "A", weight: 1.0, symmetric: false)

        #expect(g.edges.isEmpty, "Edges referencing unknown nodes must not be added")
    }

    @Test func nodeLookupByNameAndID() async throws {
        let g = Graph()
        g.addNode(name: "A", size: 1.0, color: .red)
        let a = try #require(g.node(name: "A"))

        // Lookup by id round-trips; an unknown id returns nil.
        #expect(g.node(id: a.id) == a)
        #expect(g.node(id: UUID()) == nil)
        #expect(g.node(name: "Nobody") == nil)
    }

    @Test func nodesForEdgeResolvesEndpoints() async throws {
        let g = Graph()
        g.addNode(name: "A", size: 1.0, color: .red)
        g.addNode(name: "B", size: 1.0, color: .blue)
        g.addEdge(from: "A", to: "B", weight: 1.0, symmetric: false)

        let edge = try #require(g.edges.first)
        let endpoints = try #require(g.nodesForEdge(edge))
        #expect(endpoints.count == 2)
        #expect(Set(endpoints.map { $0.name }) == ["A", "B"])
    }

}
