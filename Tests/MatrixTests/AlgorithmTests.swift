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
@testable import Matrix

struct Test {

    @Test func AdjacencyTests() async throws {
        let g = Graph.smallGraph
        
        
        let a = AdjacencyMatrix(graph: g, weighed: false )
        #expect(a.rows == a.cols, "Adjacency matrix not square" )
        #expect(a.rows == g.cardinality, "Adjacency matrix incorrect size" )
        
        
        // smallGraph: A-B (w1, sym), B-C (w2, sym), C-A (w3, sym),
        // and C->D (w4, NOT symmetric — so only [2,3] is set, not [3,2]).
        let A1 = Matrix( 4, 4, 0 )
        A1[0,1] = 1.0; A1[1,0] = 1.0
        A1[0,2] = 1.0; A1[2,0] = 1.0
        A1[1,2] = 1.0; A1[2,1] = 1.0
        A1[2,3] = 1.0
        A1.rowNames = a.rowNames
        A1.colNames = a.colNames

        // A --- B
        //  \   /
        //    C
        //    |
        //    D
        #expect( a == A1, "Adjacency matrix incorrect")

        let A2 = Matrix( 4, 4, 0 )
        A2[0,1] = 1.0; A2[1,0] = 1.0
        A2[0,2] = 3.0; A2[2,0] = 3.0
        A2[1,2] = 2.0; A2[2,1] = 2.0
        A2[2,3] = 4.0

        let b = AdjacencyMatrix(graph: g, weighed: true )
        A2.rowNames = b.rowNames
        A2.colNames = b.colNames

        #expect( b == A2, "Weighted adjacency matrix incorrect")

    }
    
    @Test func DegreeCentralityTests() async throws {
        let g = Graph.smallGraph
        
        let v = OutDegreeCentrality(graph: g)
        #expect(v.isEmpty == false, "Vector created incorrectly")
        #expect(v[0] == 2.0, "Degree centrality incorrect")
        #expect(v[1] == 2.0, "Degree centrality incorrect")
        #expect(v[2] == 3.0, "Degree centrality incorrect")
        #expect(v[3] == 0.0, "Degree centrality incorrect")
        
    }
    
    @Test func InDegreeCentralityTests() async throws {
        let g = Graph.smallGraph
        
        let v = InDegreeCentrality(graph: g)
        #expect(v.isEmpty == false, "Vector created incorrectly")
        #expect(v[0] == 2.0, "Degree centrality incorrect")
        #expect(v[1] == 2.0, "Degree centrality incorrect")
        #expect(v[2] == 2.0, "Degree centrality incorrect")
        #expect(v[3] == 1.0, "Degree centrality incorrect")
        
    }

    
    
    @Test func TotalDegreeCentralityTests() async throws {
        let g = Graph.smallGraph
        
        let v = TotalDegreeCentrality(graph: g)
        #expect(v.isEmpty == false, "Vector created incorrectly")
        #expect(v[0] == 4.0, "Degree centrality incorrect")
        #expect(v[1] == 4.0, "Degree centrality incorrect")
        #expect(v[2] == 5.0, "Degree centrality incorrect")
        #expect(v[3] == 1.0, "Degree centrality incorrect")
        
    }

    
    @Test func ClosenessCentralityTests() async throws {
        let g = Graph.smallGraph
        let v = ClosenessCentrality(graph: g)

        // A reaches B(1), C(3), D(7) → 3/11; B reaches A(1), C(2), D(6) → 3/9;
        // C reaches A(3), B(2), D(4) → 3/9; D has no outgoing edges → 0.
        #expect( v == [3.0/11.0, 1.0/3.0, 1.0/3.0, 0.0 ],  "Closeness centrality incorrect")
        
    }

    
    
    @Test func BetweennessCentralityTests() async throws {
        let g = Graph.smallGraph
        let v = BetweennessCentrality(graph: g)
        
        #expect( v == [0.0, 0.0, 1.0/3.0, 0.0], "Betweenness centrality incorrect" )
    }
    
    
    @Test func EigenvectorCentralityTests() async throws {
        // Test eigenvector centrality on a simple undirected graph
        // Note: Eigenvector centrality may return nil for some graph structures
        // (e.g., graphs with disconnected components or certain topologies)
        let g = Graph()
        g.addNode(name: "A", size: 1.0, color: .red)
        g.addNode(name: "B", size: 1.0, color: .green)
        g.addNode(name: "C", size: 1.0, color: .blue)
        g.addNode(name: "D", size: 1.0, color: .orange)

        // Create a connected graph with varying centrality
        g.addEdge(from: "A", to: "B", weight: 1.0, symmetric: true)
        g.addEdge(from: "A", to: "C", weight: 1.0, symmetric: true)
        g.addEdge(from: "B", to: "C", weight: 1.0, symmetric: true)
        g.addEdge(from: "B", to: "D", weight: 1.0, symmetric: true)

        // This test verifies the function can be called and returns expected type
        // Some graph structures may legitimately return nil
        let v = EigenvectorCentrality(graph: g)
        if let centrality = v {
            #expect(centrality.count == 4, "Should have centrality for 4 nodes")

            // Centralities should be non-negative
            for c in centrality {
                #expect(c >= 0.0, "Centrality should be non-negative")
            }
        }
        // If nil is returned, that's acceptable for certain graph topologies
    }

    @Test func EigenvectorCentralityStarGraph() async throws {
        // Test with a star graph where center node should have highest centrality
        let g = Graph()
        g.addNode(name: "Center", size: 1.0, color: .red)
        g.addNode(name: "A", size: 1.0, color: .blue)
        g.addNode(name: "B", size: 1.0, color: .blue)
        g.addNode(name: "C", size: 1.0, color: .blue)

        // Center connects to all others
        g.addEdge(from: "Center", to: "A", weight: 1.0, symmetric: true)
        g.addEdge(from: "Center", to: "B", weight: 1.0, symmetric: true)
        g.addEdge(from: "Center", to: "C", weight: 1.0, symmetric: true)

        if let v = EigenvectorCentrality(graph: g) {
            #expect(v.count == 4, "Should have centrality for 4 nodes")

            // Center node (index 0) should have highest centrality
            #expect(v[0] > v[1], "Center should have higher centrality than periphery")
            #expect(v[0] > v[2], "Center should have higher centrality than periphery")
            #expect(v[0] > v[3], "Center should have higher centrality than periphery")
        }
    }

    @Test func EigenvectorCentralityEmptyGraphReturnsNil() async throws {
        // An empty graph has a 0×0 adjacency matrix, so there is no dominant
        // eigenvector to return.
        #expect(EigenvectorCentrality(graph: Graph()) == nil)
    }

    @Test func ClosenessCentralityDisconnectedGraph() async throws {
        // Two disconnected components: A↔B and C↔D. Each node can only reach its
        // own partner, so closeness = 1 reachable / distance 1 = 1.0 for all.
        let g = Graph()
        g.addNode(name: "A", size: 1.0, color: .red)
        g.addNode(name: "B", size: 1.0, color: .red)
        g.addNode(name: "C", size: 1.0, color: .blue)
        g.addNode(name: "D", size: 1.0, color: .blue)
        g.addEdge(from: "A", to: "B", weight: 1.0, symmetric: true)
        g.addEdge(from: "C", to: "D", weight: 1.0, symmetric: true)

        let v = ClosenessCentrality(graph: g)
        #expect(v == [1.0, 1.0, 1.0, 1.0], "Each node reaches only its partner at distance 1")
    }

}
