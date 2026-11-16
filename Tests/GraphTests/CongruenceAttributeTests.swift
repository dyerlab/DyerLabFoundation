//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  CongruenceAttributeTests.swift
//  GraphTests
//
//  CongruenceTopology carries both parents' node attributes the way gstudio
//  1.15's congruence_topology() does (.congruence_vertex_attrs()).
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import CoreLocation
import Testing
@testable import Graph

struct CongruenceAttributeTests {

    /// A triangle A–B–C plus D, with each node's attributes from `attributes`.
    private func graph(sizes: [Double], continuous: [String: [Double]], categorical: [String: [String]] = [:],
                       coordinates: Bool) -> Graph {
        let names = ["A", "B", "C", "D"]
        let nodes = names.indices.map { i in
            Node(name: names[i], size: sizes[i], categoricalAttributes: categorical.mapValues { $0[i] },
                 continuousAttributes: continuous.mapValues { $0[i] })
        }
        if coordinates {
            for (i, node) in nodes.enumerated() {
                node.coordinate = CLLocationCoordinate2D(latitude: 30 + Double(i), longitude: -110)
            }
        }
        let edges = [(0, 1), (1, 2), (0, 2), (2, 3)].map { Edge(fromNode: nodes[$0.0], toNode: nodes[$0.1], weight: 1) }
        return Graph(nodes: nodes, edges: edges)
    }

    @Test func attributesFromBothGraphsAreMerged() throws {
        let g1 = graph(sizes: [1, 2, 3, 4],
                       continuous: ["Latitude": [30, 31, 32, 33], "Ho": [0.1, 0.2, 0.3, 0.4],
                                    "Ne": [10, 20, 30, 40]],
                       coordinates: false)
        let g2 = graph(sizes: [1, 2, 3, 4],
                       continuous: ["Latitude": [30, 31, 32 + 1e-12, 33], "Ne": [11, 20, 30, 40]],
                       categorical: ["Region": ["N", "N", "S", "S"]], coordinates: true)
        let cong = CongruenceTopology(g1, g2)
        let c = try #require(cong.node(name: "C"))
        #expect(c.continuousAttributes["Latitude"] == 32)              // same in both, within tolerance: once
        #expect(c.continuousAttributes["Ho"] == 0.3)                   // only in graph 1
        #expect(c.categoricalAttributes["Region"] == "S")              // only in graph 2
        #expect(c.continuousAttributes["Ne"] == nil)                   // differs: kept from both
        #expect(cong.node(name: "A")?.continuousAttributes["Ne.1"] == 10)
        #expect(cong.node(name: "A")?.continuousAttributes["Ne.2"] == 11)
        #expect(c.continuousAttributes["size.1"] == nil)               // sizes agree
        #expect(c.coordinate?.latitude == 32)                         // graph 2's, graph 1 has none
    }

    @Test func differingSizesAreKeptFromBoth() throws {
        let g1 = graph(sizes: [1, 2, 3, 4], continuous: [:], coordinates: false)
        let g2 = graph(sizes: [5, 6, 7, 8], continuous: [:], coordinates: false)
        let b = try #require(CongruenceTopology(g1, g2).node(name: "B"))
        #expect(b.size == 2)
        #expect(b.continuousAttributes["size.1"] == 2)
        #expect(b.continuousAttributes["size.2"] == 6)
    }
}
