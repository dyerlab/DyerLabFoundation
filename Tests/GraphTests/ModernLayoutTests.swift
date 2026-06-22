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
//  ModernLayoutTests.swift
//  MatrixStuffTests
//
//  Tests for the modern layout engine (ForceSolver / PhysicsIntegrator /
//  SettleDetector / EdgeState / Camera2D / LayoutState) used by
//  LayoutOrchestrator and GraphLayoutView in production.
//

import Testing
import Foundation
import simd
@testable import Graph

@Suite("Modern Layout Engine")
struct ModernLayoutTests {

    // MARK: - Force Formulas

    @Test("Repulsive force follows inverse-square law and scales with strength")
    func repulsiveForceFormula() {
        let force = repulsiveForce(k: 100.0, distance: 50.0, strength: 1.0)
        #expect(isApprox(force, (100.0 * 100.0) / (50.0 * 50.0)), "F = k²/d²")

        // Strength scales linearly.
        let doubled = repulsiveForce(k: 100.0, distance: 50.0, strength: 2.0)
        #expect(isApprox(doubled, 2.0 * force))

        // Closer nodes repel harder.
        let closer = repulsiveForce(k: 100.0, distance: 25.0, strength: 1.0)
        #expect(closer > force)
    }

    @Test("Repulsive force caps at near-zero distance")
    func repulsiveForceCap() {
        #expect(repulsiveForce(k: 100.0, distance: 0.0) == 10000.0)
        #expect(repulsiveForce(k: 100.0, distance: 0.001) == 10000.0)
    }

    @Test("Attractive force is zero at ideal length and signed by displacement")
    func attractiveForceSign() {
        #expect(attractiveForce(distance: 100.0, idealLength: 100.0) == 0.0)
        #expect(attractiveForce(distance: 150.0, idealLength: 100.0) > 0.0, "Too far → pull together")
        #expect(attractiveForce(distance: 50.0, idealLength: 100.0) < 0.0, "Too close → push apart")
    }

    @Test("Center gravity points toward origin")
    func centerGravity() {
        let f = centerGravityForce(position: SIMD3<Float>(10, -4, 0), strength: 2.0)
        #expect(f.x == -20.0)
        #expect(f.y == 8.0)
    }

    // MARK: - computeForces

    @Test("Computed forces are finite and sized to the node count")
    func computeForcesFinite() {
        let graph = Graph.smallGraph
        let state = LayoutState(nodeCount: graph.nodes.count)
        var rng = SeededGenerator(seed: 1)
        for i in 0..<state.nodeCount {
            state.positions[i] = SIMD3<Float>(
                Float.random(in: -200...200, using: &rng),
                Float.random(in: -200...200, using: &rng),
                0
            )
        }
        let edges = EdgeStateManager(edgeCount: graph.edges.count)
        let config = LayoutConfiguration()

        let forces = computeForces(state: state, graph: graph, edgeStates: edges, config: config)

        #expect(forces.count == state.nodeCount)
        for f in forces {
            #expect(f.x.isFinite && f.y.isFinite && f.z.isFinite, "Forces must be finite")
        }
    }

    @Test("Two unconnected nodes repel symmetrically (Newton's third law)")
    func repulsionIsSymmetric() {
        let graph = Graph()
        graph.addNode(name: "A", size: 1.0, color: .red)
        graph.addNode(name: "B", size: 1.0, color: .blue)
        // No edges.

        let state = LayoutState(nodeCount: 2)
        state.positions[0] = SIMD3<Float>(-10, 0, 0)
        state.positions[1] = SIMD3<Float>(10, 0, 0)

        var config = LayoutConfiguration()
        config.centerGravity = 0          // isolate repulsion
        config.useCollisionDetection = false

        let forces = computeForces(
            state: state,
            graph: graph,
            edgeStates: EdgeStateManager(edgeCount: 0),
            config: config
        )

        #expect(forces[0].x < 0, "Left node pushed further left")
        #expect(forces[1].x > 0, "Right node pushed further right")
        #expect(isApprox(forces[0].x, -forces[1].x), "Equal and opposite")
    }

    @Test("A stretched edge pulls its endpoints together")
    func attractionPullsTogether() {
        let graph = Graph()
        graph.addNode(name: "A", size: 1.0, color: .red)
        graph.addNode(name: "B", size: 1.0, color: .blue)
        // Light edge → short ideal length (0.1 * k = 10), nodes are 20 apart → stretched.
        graph.addEdge(from: "A", to: "B", weight: 0.1, symmetric: false)

        let state = LayoutState(nodeCount: 2)
        state.positions[0] = SIMD3<Float>(-10, 0, 0)
        state.positions[1] = SIMD3<Float>(10, 0, 0)

        var config = LayoutConfiguration()
        config.k = 100.0
        config.repulsionStrength = 0      // isolate attraction
        config.centerGravity = 0
        config.useCollisionDetection = false

        let forces = computeForces(
            state: state,
            graph: graph,
            edgeStates: EdgeStateManager(edgeCount: graph.edges.count),
            config: config
        )

        #expect(forces[0].x > 0, "Left endpoint pulled right toward partner")
        #expect(forces[1].x < 0, "Right endpoint pulled left toward partner")
    }

    @Test("2D mode flattens the z force toward the plane")
    func zFlattening() {
        let graph = Graph()
        graph.addNode(name: "A", size: 1.0, color: .red)

        let state = LayoutState(nodeCount: 1)
        state.positions[0] = SIMD3<Float>(0, 0, 5)

        var config = LayoutConfiguration()
        config.mode2D = true
        config.centerGravity = 0
        config.useCollisionDetection = false

        let forces = computeForces(
            state: state,
            graph: graph,
            edgeStates: EdgeStateManager(edgeCount: 0),
            config: config
        )

        // ForceSolver overwrites z with -position.z * zFlatteningStrength.
        #expect(isApprox(forces[0].z, -5.0 * config.zFlatteningStrength))
    }

    // MARK: - PhysicsIntegrator

    @Test("Integration moves an unpinned node along the applied force")
    func integrateMovesNode() {
        var state = LayoutState(nodeCount: 1)
        state.positions[0] = .zero
        let config = LayoutConfiguration()

        integrate(
            state: &state,
            forces: [SIMD3<Float>(100, 0, 0)],
            config: config,
            temperature: Float(config.initialTemperature)
        )

        #expect(state.velocities[0].x > 0, "Velocity should build in the force direction")
        #expect(state.positions[0].x > 0, "Position should advance in the force direction")
    }

    @Test("Pinned nodes snap to target and hold zero velocity")
    func integratePinnedNode() {
        var state = LayoutState(nodeCount: 1)
        state.positions[0] = SIMD3<Float>(-100, -100, 0)
        state.velocities[0] = SIMD3<Float>(50, 50, 0)
        state.pinned[0] = true
        state.pinnedTargets[0] = SIMD3<Float>(7, 8, 0)

        integrate(
            state: &state,
            forces: [SIMD3<Float>(999, 999, 0)],
            config: LayoutConfiguration(),
            temperature: 100.0
        )

        #expect(state.positions[0] == SIMD3<Float>(7, 8, 0))
        #expect(state.velocities[0] == .zero)
    }

    @Test("Exponential and linear cooling reduce temperature")
    func coolingSchedules() {
        var config = LayoutConfiguration()
        config.coolingFactor = 0.9
        #expect(isApprox(updateTemperature(current: 100.0, config: config), 90.0))

        #expect(linearCooling(initial: 100.0, iteration: 0, maxIterations: 100) == 100.0)
        #expect(linearCooling(initial: 100.0, iteration: 50, maxIterations: 100) == 50.0)
        #expect(linearCooling(initial: 100.0, iteration: 100, maxIterations: 100) == 0.0)
    }

    // MARK: - SettleDetector

    @Test("Settle detector fires only after enough consecutive quiet frames")
    func settleDetector() {
        let detector = SettleDetector(threshold: 1.0, requiredFrames: 3)

        #expect(detector.update(kineticEnergy: 0.5) == false)
        #expect(detector.update(kineticEnergy: 0.5) == false)
        #expect(detector.update(kineticEnergy: 0.5) == true, "Settles on the 3rd quiet frame")
    }

    @Test("A spike in energy resets the settle counter")
    func settleDetectorReset() {
        let detector = SettleDetector(threshold: 1.0, requiredFrames: 3)
        _ = detector.update(kineticEnergy: 0.1)
        _ = detector.update(kineticEnergy: 0.1)
        #expect(detector.update(kineticEnergy: 100.0) == false, "Energy spike resets the counter")
        #expect(detector.settledFrameCount == 0)
    }

    // MARK: - EdgeState

    @Test("Edge activation ramps toward its target and clamps")
    func edgeStateRamp() {
        var edge = EdgeState(alpha: 0.0, targetAlpha: 1.0, rampSpeed: 2.0)
        edge.update(deltaTime: 0.25)
        #expect(isApprox(edge.alpha, 0.5))
        edge.update(deltaTime: 0.25)
        #expect(isApprox(edge.alpha, 1.0))
        edge.update(deltaTime: 0.25)
        #expect(edge.alpha == 1.0, "Should clamp at target, not overshoot")
    }

    @Test("EdgeStateManager ramps all edges and sets values immediately")
    func edgeStateManager() {
        let manager = EdgeStateManager(edgeCount: 3, initialAlpha: 0.0)
        manager.rampAll(to: 1.0, duration: 0.5)   // speed = 2.0 per second
        manager.updateAll(deltaTime: 0.25)
        for s in manager.states {
            #expect(isApprox(s.alpha, 0.5))
        }

        manager.setImmediate(index: 1, alpha: 0.3)
        #expect(manager.states[1].alpha == 0.3)
        #expect(manager.states[1].targetAlpha == 0.3)
    }

    // MARK: - Camera2D

    @Test("World↔view transforms round-trip")
    func cameraRoundTrip() {
        let camera = Camera2D(zoom: 2.0, pan: SIMD2<Float>(5, -7))
        let canvas = CGSize(width: 200, height: 200)

        let world = SIMD3<Float>(30, 40, 0)
        let view = worldToView(worldPoint: world, canvasSize: canvas, camera: camera)
        let back = viewToWorld(viewPoint: view, canvasSize: canvas, camera: camera)

        #expect(isApprox(back.x, world.x))
        #expect(isApprox(back.y, world.y))
    }

    @Test("Hit testing finds a node within its radius and misses outside")
    func cameraHitTest() {
        let state = LayoutState(nodeCount: 1)
        state.positions[0] = .zero
        state.radii[0] = 10
        let camera = Camera2D()
        let canvas = CGSize(width: 100, height: 100)   // center at (50,50)

        // Directly over the node.
        #expect(hitTest(viewPoint: CGPoint(x: 50, y: 50), state: state, camera: camera, canvasSize: canvas) == 0)
        // Within the radius.
        #expect(hitTest(viewPoint: CGPoint(x: 55, y: 50), state: state, camera: camera, canvasSize: canvas) == 0)
        // Outside the radius.
        #expect(hitTest(viewPoint: CGPoint(x: 80, y: 50), state: state, camera: camera, canvasSize: canvas) == nil)
    }

    @Test("Fit-to-view handles a single node without dividing by zero")
    func cameraFitDegenerate() {
        let state = LayoutState(nodeCount: 1)
        state.positions[0] = .zero

        let camera = fitToView(state: state, canvasSize: CGSize(width: 400, height: 400))

        #expect(camera.zoom.isFinite)
        #expect(camera.zoom > 0)
    }

    // MARK: - LayoutState

    @Test("LayoutState initializes parallel arrays and computes kinetic energy")
    func layoutStateBasics() {
        let state = LayoutState(nodeCount: 3)

        #expect(state.positions.count == 3)
        #expect(state.velocities.count == 3)
        #expect(state.radii.count == 3)
        #expect(state.pinned.allSatisfy { $0 == false })
        #expect(state.kineticEnergy == 0.0)

        state.velocities[0] = SIMD3<Float>(3, 4, 0)   // |v|² = 25
        #expect(isApprox(state.kineticEnergy, 25.0))

        state.scaleVelocities(by: 0.5)                // |v|² = 6.25
        #expect(isApprox(state.kineticEnergy, 6.25))

        state.resetVelocities()
        #expect(state.kineticEnergy == 0.0)
    }
}
