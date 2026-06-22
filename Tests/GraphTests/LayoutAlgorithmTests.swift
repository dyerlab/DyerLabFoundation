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
//  LayoutAlgorithmTests.swift
//  MatrixStuffTests
//
//  Unit tests for force-directed layout algorithm components.
//

import Testing
import Foundation
@testable import Graph

/// Tests for Fruchterman-Reingold force calculations.
@Suite("Force-Directed Layout Algorithm")
struct LayoutAlgorithmTests {

    // MARK: - Repulsive Force Tests

    @Test("Repulsive force is positive")
    func repulsiveForceIsPositive() {
        let k = 100.0
        let distance = 50.0
        let force = ForceDirectedLayout.repulsiveForce(k: k, distance: distance)

        #expect(force > 0, "Repulsive force should always be positive")
    }

    @Test("Repulsive force formula is correct (inverse square law)")
    func repulsiveForceFormula() {
        let k = 100.0
        let distance = 50.0
        let force = ForceDirectedLayout.repulsiveForce(k: k, distance: distance)

        let expected = (k * k) / (distance * distance)
        #expect(force == expected, "Force should equal k²/d² (inverse square law)")
    }

    @Test("Repulsive force increases as distance decreases")
    func repulsiveForceInverseDistance() {
        let k = 100.0
        let force1 = ForceDirectedLayout.repulsiveForce(k: k, distance: 100.0)
        let force2 = ForceDirectedLayout.repulsiveForce(k: k, distance: 50.0)

        #expect(force2 > force1, "Force should increase as distance decreases")
    }

    @Test("Repulsive force handles zero distance with cap")
    func repulsiveForceZeroDistance() {
        let k = 100.0
        let force = ForceDirectedLayout.repulsiveForce(k: k, distance: 0.0)

        #expect(force == 10000.0, "Very small distance should return capped force to prevent infinity")
    }

    // MARK: - Attractive Force Tests

    @Test("Attractive force with ideal length")
    func attractiveForceAtIdealLength() {
        let k = 100.0
        let idealLength = 100.0
        let force = ForceDirectedLayout.attractiveForce(k: k, distance: idealLength, idealLength: idealLength)

        #expect(force == 0.0, "Force should be zero at ideal length")
    }

    @Test("Attractive force pulls nodes together when too far")
    func attractiveForcePullsTogether() {
        let k = 100.0
        let idealLength = 100.0
        let distance = 150.0  // Farther than ideal

        let force = ForceDirectedLayout.attractiveForce(k: k, distance: distance, idealLength: idealLength)

        #expect(force > 0, "Force should be positive (attractive) when distance > ideal length")
    }

    @Test("Attractive force pushes nodes apart when too close")
    func attractiveForcePushesApart() {
        let k = 100.0
        let idealLength = 100.0
        let distance = 50.0  // Closer than ideal

        let force = ForceDirectedLayout.attractiveForce(k: k, distance: distance, idealLength: idealLength)

        #expect(force < 0, "Force should be negative (repulsive) when distance < ideal length")
    }

    @Test("Edge weight affects ideal spring length")
    func edgeWeightScalesSpringLength() {
        // Ideal spring length scales with edge weight: idealLength = weight * k.
        // Verify the relationship through the real attractive-force function rather
        // than re-deriving it in the test: at the ideal length the force is zero,
        // and a heavier edge (longer ideal length) turns the same physical distance
        // into a "too close" spring that pushes apart (negative force).
        let k = 100.0
        let lightIdeal = 1.0 * k   // weight 1 → ideal 100
        let heavyIdeal = 2.0 * k   // weight 2 → ideal 200

        #expect(ForceDirectedLayout.attractiveForce(k: k, distance: lightIdeal, idealLength: lightIdeal) == 0.0,
                "Force should be zero at the light edge's ideal length")
        #expect(ForceDirectedLayout.attractiveForce(k: k, distance: lightIdeal, idealLength: heavyIdeal) < 0.0,
                "At the same distance, a heavier edge's longer ideal length should push apart")
    }

    // MARK: - Force Computation Tests

    @Test("Compute forces for simple graph")
    func computeForcesSimpleGraph() {
        let graph = Graph.smallGraph
        var rng = SeededGenerator(seed: 42)
        graph.initializeRandomLayout(in: CGRect(x: 0, y: 0, width: 500, height: 500), using: &rng)

        let forces = ForceDirectedLayout.computeForces(
            graph: graph,
            k: 100.0,
            repulsionStrength: 1.0,
            centerGravity: 0.1,
            bounds: CGRect(x: 0, y: 0, width: 500, height: 500)
        )

        #expect(forces.count == graph.cardinality, "Should have forces for all nodes")

        for (_, force) in forces {
            #expect(!force.dx.isNaN, "Force dx should not be NaN")
            #expect(!force.dy.isNaN, "Force dy should not be NaN")
            #expect(!force.dx.isInfinite, "Force dx should not be infinite")
            #expect(!force.dy.isInfinite, "Force dy should not be infinite")
        }
    }

    @Test("Center gravity pulls nodes toward center")
    func centerGravityPullsToCenter() {
        let graph = Graph.smallGraph
        let bounds = CGRect(x: 0, y: 0, width: 500, height: 500)

        // Place nodes off-center
        for node in graph.nodes {
            node.layoutCoordinate = CGPoint(x: 100, y: 100)  // Top-left corner
        }

        let forces = ForceDirectedLayout.computeForces(
            graph: graph,
            k: 100.0,
            repulsionStrength: 0.0,  // Disable repulsion to isolate gravity effect
            centerGravity: 1.0,
            bounds: bounds
        )

        // All nodes should have forces pointing toward center
        for (_, force) in forces {
            #expect(force.dx > 0, "Force should pull right toward center")
            #expect(force.dy > 0, "Force should pull down toward center")
        }
    }

    @Test("Isolated nodes have near-zero net force")
    func isolatedNodesZeroForce() {
        // Create a graph with single isolated node at center
        let graph = Graph()
        let bounds = CGRect(x: 0, y: 0, width: 500, height: 500)
        graph.addNode(name: "A", size: 1.0, color: .red)
        graph.nodes[0].layoutCoordinate = CGPoint(x: bounds.midX, y: bounds.midY)

        let forces = ForceDirectedLayout.computeForces(
            graph: graph,
            k: 100.0,
            repulsionStrength: 1.0,
            centerGravity: 0.0,  // No gravity for this test
            bounds: bounds
        )

        #expect(forces.count == 1)
        let force = forces.values.first!
        #expect(abs(force.dx) < 0.01 && abs(force.dy) < 0.01, "Single isolated node at center should have near-zero force")
    }

    // MARK: - Boundary Force Tests

    @Test("Boundary forces push nodes away from edges")
    func boundaryForcesPushInward() {
        let graph = Graph()
        graph.addNode(name: "A", size: 1.0, color: .red)

        let bounds = CGRect(x: 0, y: 0, width: 500, height: 500)

        // Place node near left edge
        let node = graph.nodes.first!
        node.layoutCoordinate = CGPoint(x: 10, y: 250)  // Near left edge

        var forces: [UUID: CGVector] = [node.id: .zero]

        ForceDirectedLayout.addBoundaryForces(
            forces: &forces,
            graph: graph,
            bounds: bounds,
            strength: 1000.0
        )

        let force = forces[node.id]!
        #expect(force.dx > 0, "Boundary force should push node away from left edge (positive dx)")
    }

    // MARK: - Cooling Schedule Tests

    @Test("Temperature decreases with cooling")
    func temperatureDecreases() {
        let initial = 100.0
        let coolingFactor = 0.95
        let cooled = ForceDirectedLayout.updateTemperature(current: initial, coolingFactor: coolingFactor)

        #expect(cooled < initial, "Temperature should decrease")
        #expect(cooled == initial * coolingFactor)
    }

    @Test("Linear cooling reaches zero")
    func linearCoolingReachesZero() {
        let initial = 100.0
        let maxIterations = 100

        let temp0 = ForceDirectedLayout.linearCooling(initial: initial, iteration: 0, maxIterations: maxIterations)
        let temp50 = ForceDirectedLayout.linearCooling(initial: initial, iteration: 50, maxIterations: maxIterations)
        let temp100 = ForceDirectedLayout.linearCooling(initial: initial, iteration: 100, maxIterations: maxIterations)

        #expect(temp0 == initial, "Temperature should be initial at iteration 0")
        #expect(temp50 == initial * 0.5, "Temperature should be half at 50% progress")
        #expect(temp100 == 0.0, "Temperature should be zero at max iterations")
    }

    // MARK: - Graph Extension Tests

    @Test("Initialize random layout sets all layoutCoordinates")
    func initializeRandomLayoutSetsCoordinates() {
        let graph = Graph.smallGraph
        let bounds = CGRect(x: 0, y: 0, width: 500, height: 500)

        var rng = SeededGenerator(seed: 42)
        graph.initializeRandomLayout(in: bounds, using: &rng)

        for node in graph.nodes {
            #expect(node.layoutCoordinate != nil, "All nodes should have layoutCoordinate")

            let pos = node.layoutCoordinate!
            #expect(pos.x >= bounds.minX && pos.x <= bounds.maxX, "X should be within bounds")
            #expect(pos.y >= bounds.minY && pos.y <= bounds.maxY, "Y should be within bounds")
        }
    }

    @Test("Layout bounding box computes correct bounds")
    func layoutBoundingBoxCorrect() {
        let graph = Graph()
        graph.addNode(name: "A", size: 1.0, color: .red)
        graph.addNode(name: "B", size: 1.0, color: .blue)
        graph.addNode(name: "C", size: 1.0, color: .green)

        graph.nodes[0].layoutCoordinate = CGPoint(x: 100, y: 100)
        graph.nodes[1].layoutCoordinate = CGPoint(x: 300, y: 200)
        graph.nodes[2].layoutCoordinate = CGPoint(x: 200, y: 400)

        let bbox = graph.layoutBoundingBox()

        #expect(bbox != nil)
        #expect(bbox!.minX == 100)
        #expect(bbox!.maxX == 300)
        #expect(bbox!.minY == 100)
        #expect(bbox!.maxY == 400)
        #expect(bbox!.width == 200)
        #expect(bbox!.height == 300)
    }

    @Test("Layout bounding box returns nil for empty graph")
    func layoutBoundingBoxEmptyGraph() {
        let graph = Graph()
        let bbox = graph.layoutBoundingBox()

        #expect(bbox == nil, "Empty graph should return nil bounding box")
    }
}
