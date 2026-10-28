//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RealityGraphEntityBuilderTests.swift
//  GraphTests
//
//  Created by Rodney Dyer on 2026.08.09.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Testing
import RealityKit
import SwiftUI
@testable import Graph

@MainActor
struct RealityGraphEntityBuilderTests {

    @Test func edgeDistanceLimitBracketsIdealLength() {
        let limit = RealityGraphEntityBuilder.edgeDistanceLimit(idealLength: 100.0, tolerance: 0.05)
        #expect(isApprox(limit.lowerBound, 95.0))
        #expect(isApprox(limit.upperBound, 105.0))
        #expect(limit.contains(100.0))
    }

    @Test func edgeDistanceLimitHandlesZeroTolerance() {
        let limit = RealityGraphEntityBuilder.edgeDistanceLimit(idealLength: 42.0, tolerance: 0.0)
        #expect(limit == 42.0...42.0)
    }

    @Test func makeNodeEntitiesMatchesGraphNodesOrder() {
        let graph = Graph.smallGraph
        let entities = RealityGraphEntityBuilder.makeNodeEntities(for: graph, options: RealityGraphOptions())
        #expect(entities.count == graph.nodes.count)
        for (entity, node) in zip(entities, graph.nodes) {
            #expect(entity.name == node.name)
        }
    }

    @Test func attachPhysicsAddsComponentsAndOneJointPerEdge() {
        let graph = Graph.smallGraph
        let entities = RealityGraphEntityBuilder.makeNodeEntities(for: graph, options: RealityGraphOptions())
        let joints = RealityGraphEntityBuilder.attachPhysics(nodeEntities: entities, graph: graph)

        #expect(joints.count == graph.edges.count)
        for entity in entities {
            #expect(entity.components.has(PhysicsBodyComponent.self))
            #expect(entity.components.has(CollisionComponent.self))
            #expect(entity.components.has(InputTargetComponent.self))
        }
    }

    /// The rest length is the settled layout's edge length, not `weight × k`:
    /// physics must start in equilibrium so the handoff doesn't snap the layout.
    @Test func attachPhysicsJointRestsAtSettledEdgeLength() throws {
        let graph = Graph()
        graph.addNode(name: "A", size: 1.0, color: .red)
        graph.addNode(name: "B", size: 1.0, color: .blue)
        graph.addEdge(from: "A", to: "B", weight: 2.0, symmetric: false)

        let entities = RealityGraphEntityBuilder.makeNodeEntities(for: graph, options: RealityGraphOptions())
        entities[0].position = SIMD3<Float>(0, 0, 0)
        entities[1].position = SIMD3<Float>(30, 40, 0)   // 50 apart; weight × k would be 400
        let joints = RealityGraphEntityBuilder.attachPhysics(nodeEntities: entities, graph: graph)

        let joint = try #require(joints.first)
        let expected = RealityGraphEntityBuilder.edgeDistanceLimit(idealLength: 50.0, tolerance: 0.05)
        #expect(joint.distanceLimit == expected)
    }

    @Test func syncPositionsWritesEntityTransformsFromLayoutState() {
        let graph = Graph.smallGraph
        let entities = RealityGraphEntityBuilder.makeNodeEntities(for: graph, options: RealityGraphOptions())
        let state = LayoutState(nodeCount: graph.nodes.count)
        state.positions[0] = SIMD3<Float>(1, 2, 3)

        RealityGraphEntityBuilder.syncPositions(entities, from: state)

        #expect(entities[0].position == SIMD3<Float>(1, 2, 3))
    }
}
