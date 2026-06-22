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

import Testing
import SwiftUI
@testable import Graph


struct PathTests {

    @Test func emptyPath() async throws {
        let g = Graph()
        let p = g.shortestPath(from: "A", to: "B")
        #expect( p == nil, "not nil path from empty graph")

    }

    @Test func noPathBetweenDisconnectedComponents() async throws {
        // A↔B and C↔D are separate components; there is no route from A to D.
        let g = Graph()
        g.addNode(name: "A", size: 1.0, color: .red)
        g.addNode(name: "B", size: 1.0, color: .red)
        g.addNode(name: "C", size: 1.0, color: .blue)
        g.addNode(name: "D", size: 1.0, color: .blue)
        g.addEdge(from: "A", to: "B", weight: 1.0, symmetric: true)
        g.addEdge(from: "C", to: "D", weight: 1.0, symmetric: true)

        #expect(g.shortestPath(from: "A", to: "D") == nil, "No path across components")

        // A directed edge gives no reverse path.
        let d = Graph()
        d.addNode(name: "X", size: 1.0, color: .red)
        d.addNode(name: "Y", size: 1.0, color: .red)
        d.addEdge(from: "X", to: "Y", weight: 1.0, symmetric: false)
        #expect(d.shortestPath(from: "Y", to: "X") == nil, "Directed edge has no reverse path")
    }
    
    @Test func lophoPaths() async throws {
        
        let graph = Graph.lophoGraph
        
        let dist1 = try #require( graph.shortestPath(from: "BaC", to: "LaV"))
        #expect( dist1.distance == 9.052676, "BaC to LaV not correct." )

        let dist2 = try #require( graph.shortestPath(from: "LaV", to: "BaC"))
        #expect( dist2.distance == 9.052676, "LaV to BaC not correct." )

        #expect( dist1.distance == dist2.distance, "Symmetrical distances are not equal.")

        let dist3 = try #require( graph.shortestPath(from: "BaC", to: "BaC"))
        #expect( dist3.distance == 0.0, "BaC to BaC not correct." )

        let dist4 = try #require( graph.shortestPath(from: "TsS", to: "Lig"))
        #expect( dist4.distance == (4.821284 + 9.026984), "TsS to Lig not correct." )
    }

}
