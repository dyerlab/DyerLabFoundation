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
//  LayoutSimulationTests.swift
//  MatrixStuffTests
//
//  Integration tests for layout simulation engine.
//

import Testing
import Foundation
@testable import Graph

/// Tests for the physics simulation engine.
@Suite("Layout Simulation Integration")
struct LayoutSimulationTests {

    // MARK: - Initialization Tests

    @Test("Simulation initializes with correct state")
    func simulationInitialization() {
        let graph = Graph.smallGraph
        var rng = SeededGenerator(seed: 42)
        graph.initializeRandomLayout(in: CGRect(x: 0, y: 0, width: 500, height: 500), using: &rng)

        let config = LayoutConfiguration()
        let simulation = LayoutSimulation(graph: graph, configuration: config)

        #expect(simulation.iteration == 0, "Should start at iteration 0")
        #expect(simulation.temperature == config.initialTemperature, "Should have initial temperature")
        #expect(simulation.hasConverged == false, "Should not be converged initially")
    }

    // MARK: - Simulation Step Tests

    @Test("Single simulation step updates state")
    func singleStepUpdatesState() {
        let graph = Graph.smallGraph
        var rng = SeededGenerator(seed: 42)
        graph.initializeRandomLayout(in: CGRect(x: 0, y: 0, width: 500, height: 500), using: &rng)

        let simulation = LayoutSimulation(graph: graph)
        let initialTemp = simulation.temperature

        simulation.step()

        #expect(simulation.iteration == 1, "Iteration should increment")
        #expect(simulation.temperature < initialTemp, "Temperature should decrease")
    }

    @Test("Simulation updates node positions")
    func simulationUpdatesPositions() {
        let graph = Graph.smallGraph
        var rng = SeededGenerator(seed: 42)
        graph.initializeRandomLayout(in: CGRect(x: 0, y: 0, width: 500, height: 500), using: &rng)

        // Store initial positions
        let initialPositions = graph.nodes.map { $0.layoutCoordinate! }

        let simulation = LayoutSimulation(graph: graph)

        // Run a few steps
        for _ in 0..<10 {
            simulation.step()
        }

        // Check that at least some positions changed
        var positionsChanged = false
        for (i, node) in graph.nodes.enumerated() {
            let currentPos = node.layoutCoordinate!
            let initialPos = initialPositions[i]

            if abs(currentPos.x - initialPos.x) > 0.1 || abs(currentPos.y - initialPos.y) > 0.1 {
                positionsChanged = true
                break
            }
        }

        #expect(positionsChanged, "At least some node positions should change after 10 steps")
    }

    // MARK: - Convergence Tests

    @Test("Simulation eventually converges")
    func simulationConverges() async throws {
        let graph = Graph.smallGraph
        let config = LayoutConfiguration()
        var rng = SeededGenerator(seed: 42)
        graph.initializeRandomLayout(in: config.bounds, using: &rng)

        let simulation = LayoutSimulation(graph: graph, configuration: config)

        var converged = false
        simulation.onConverged = {
            converged = true
        }

        // Run for max iterations
        for _ in 0..<1000 {
            simulation.step()
            if converged { break }
        }

        #expect(converged, "Layout should converge within max iterations")
        #expect(simulation.hasConverged, "hasConverged flag should be set")
    }

    @Test("Converged simulation stops stepping")
    func convergedSimulationStops() {
        let graph = Graph.smallGraph
        var rng = SeededGenerator(seed: 42)
        graph.initializeRandomLayout(in: CGRect(x: 0, y: 0, width: 500, height: 500), using: &rng)

        let simulation = LayoutSimulation(graph: graph)

        // Force convergence by running many steps
        for _ in 0..<1000 {
            simulation.step()
        }

        #expect(simulation.hasConverged, "Should be converged after 1000 steps")

        let finalIteration = simulation.iteration

        // Try stepping again
        simulation.step()

        #expect(simulation.iteration == finalIteration, "Should not step further after convergence")
    }

    // MARK: - Callback Tests

    @Test("onUpdate callback is invoked")
    func updateCallbackInvoked() {
        let graph = Graph.smallGraph
        var rng = SeededGenerator(seed: 42)
        graph.initializeRandomLayout(in: CGRect(x: 0, y: 0, width: 500, height: 500), using: &rng)

        let simulation = LayoutSimulation(graph: graph)

        var callbackCount = 0
        simulation.onUpdate = { _, _ in
            callbackCount += 1
        }

        simulation.step()

        #expect(callbackCount == 1, "Callback should be invoked once per step")
    }

    @Test("onIteration callback receives correct values")
    func iterationCallbackCorrect() {
        let graph = Graph.smallGraph
        var rng = SeededGenerator(seed: 42)
        graph.initializeRandomLayout(in: CGRect(x: 0, y: 0, width: 500, height: 500), using: &rng)

        let simulation = LayoutSimulation(graph: graph)

        var receivedIteration: Int?
        var receivedTemp: Double?

        simulation.onIteration = { iter, temp in
            receivedIteration = iter
            receivedTemp = temp
        }

        simulation.step()

        #expect(receivedIteration == 1)
        #expect(receivedTemp != nil)
        #expect(receivedTemp! < simulation.configuration.initialTemperature)
    }

    // MARK: - Reset Tests

    @Test("Reset clears simulation state")
    func resetClearsState() {
        let graph = Graph.smallGraph
        var rng = SeededGenerator(seed: 42)
        graph.initializeRandomLayout(in: CGRect(x: 0, y: 0, width: 500, height: 500), using: &rng)

        let simulation = LayoutSimulation(graph: graph)
        let initialTemp = simulation.temperature

        // Run some steps
        for _ in 0..<10 {
            simulation.step()
        }

        #expect(simulation.iteration > 0)
        #expect(simulation.temperature < initialTemp)

        // Reset
        simulation.reset()

        #expect(simulation.iteration == 0, "Iteration should reset to 0")
        #expect(simulation.temperature == initialTemp, "Temperature should reset to initial")
        #expect(simulation.hasConverged == false, "hasConverged should reset to false")
    }

    // MARK: - Energy Tests

    @Test("Energy decreases over time")
    func energyDecreases() {
        let graph = Graph.smallGraph
        var rng = SeededGenerator(seed: 42)
        graph.initializeRandomLayout(in: CGRect(x: 0, y: 0, width: 500, height: 500), using: &rng)

        let simulation = LayoutSimulation(graph: graph)

        // Let system settle for a bit first (skip initial high-energy phase)
        for _ in 0..<20 {
            simulation.step()
        }

        let initialEnergy = simulation.averageEnergy()

        // Run more steps with slower cooling schedule (0.99 cooling factor needs more iterations)
        for _ in 0..<100 {
            simulation.step()
        }

        let finalEnergy = simulation.averageEnergy()

        #expect(finalEnergy < initialEnergy, "Energy should decrease as layout stabilizes")
    }

    @Test("Progress increases correctly")
    func progressIncreasesCorrectly() {
        let graph = Graph.smallGraph
        var rng = SeededGenerator(seed: 42)
        graph.initializeRandomLayout(in: CGRect(x: 0, y: 0, width: 500, height: 500), using: &rng)

        var config = LayoutConfiguration()
        config.maxIterations = 100
        // Disable early convergence so `progress` depends only on the iteration
        // count. Otherwise the sim could settle (and stop incrementing) before
        // iteration 100, leaving progress < 1.0 — a flaky, init-dependent failure.
        config.convergenceThreshold = 0.0

        let simulation = LayoutSimulation(graph: graph, configuration: config)

        #expect(simulation.progress == 0.0, "Progress should be 0 at start")

        // Run to halfway
        for _ in 0..<50 {
            simulation.step()
        }

        #expect(simulation.progress == 0.5, "Progress should be 0.5 at halfway point")

        // Run to end
        for _ in 0..<50 {
            simulation.step()
        }

        #expect(simulation.progress == 1.0, "Progress should be 1.0 at max iterations")
    }

    // MARK: - Boundary Constraint Tests

    @Test("Boundary forces keep nodes within bounds")
    func boundaryConstraintsWork() {
        let graph = Graph.smallGraph
        let bounds = CGRect(x: 0, y: 0, width: 500, height: 500)

        var config = LayoutConfiguration()
        config.bounds = bounds
        config.useBoundaryForces = true

        var rng = SeededGenerator(seed: 42)
        graph.initializeRandomLayout(in: bounds, using: &rng)

        let simulation = LayoutSimulation(graph: graph, configuration: config)

        // Run simulation
        for _ in 0..<100 {
            simulation.step()
        }

        // Check that most nodes are within bounds (allow small margin for edge cases)
        let margin = 100.0  // Soft boundaries may extend slightly beyond
        let expandedBounds = bounds.insetBy(dx: -margin, dy: -margin)

        var nodesInBounds = 0
        for node in graph.nodes {
            if let pos = node.layoutCoordinate {
                if expandedBounds.contains(pos) {
                    nodesInBounds += 1
                }
            }
        }

        let percentageInBounds = Double(nodesInBounds) / Double(graph.cardinality)
        #expect(percentageInBounds > 0.8, "At least 80% of nodes should be within bounds")
    }

    // MARK: - Large Graph Tests

    @Test("Simulation handles larger graph (lophoGraph)")
    func largeGraphSimulation() {
        let graph = Graph.lophoGraph  // 21 nodes
        let config = LayoutConfiguration.largeGraph
        var rng = SeededGenerator(seed: 42)
        graph.initializeRandomLayout(in: config.bounds, using: &rng)

        let simulation = LayoutSimulation(graph: graph, configuration: config)

        var converged = false
        simulation.onConverged = {
            converged = true
        }

        // Run for max iterations
        for _ in 0..<config.maxIterations {
            simulation.step()
            if converged { break }
        }

        // Should converge or at least run without errors
        #expect(simulation.iteration > 0)
        #expect(simulation.hasConverged || simulation.iteration >= config.maxIterations)
    }

    // MARK: - Edge Weight Tests

    @Test("Edge weights affect final layout")
    func edgeWeightsAffectLayout() {
        // Create two connected nodes with specific edge weight
        let graph = Graph()
        graph.addNode(name: "A", size: 1.0, color: .red)
        graph.addNode(name: "B", size: 1.0, color: .blue)
        graph.addEdge(from: "A", to: "B", weight: 5.0, symmetric: true)  // Large weight = long ideal length

        let config = LayoutConfiguration()
        var rng = SeededGenerator(seed: 42)
        graph.initializeRandomLayout(in: config.bounds, using: &rng)

        let simulation = LayoutSimulation(graph: graph, configuration: config)

        // Run to convergence
        for _ in 0..<500 {
            simulation.step()
        }

        // Measure final distance
        let posA = graph.nodes[0].layoutCoordinate!
        let posB = graph.nodes[1].layoutCoordinate!
        let distance = hypot(posB.x - posA.x, posB.y - posA.y)

        // Distance should be influenced by weight * k, but won't match exactly
        // due to other forces (repulsion between nodes, boundary forces, etc.)
        // We just verify it's within a reasonable range
        let expectedDistance = 5.0 * config.k

        #expect(distance > expectedDistance * 0.3, "Distance should not be too small")
        #expect(distance < expectedDistance * 2.0, "Distance should not be too large")
    }

    // MARK: - Configuration Tests

    @Test("Configuration presets are valid")
    func configurationPresetsValid() {
        let defaultConfig = LayoutConfiguration.default
        let smallConfig = LayoutConfiguration.smallGraph
        let largeConfig = LayoutConfiguration.largeGraph

        #expect(defaultConfig.k > 0)
        #expect(smallConfig.k > 0)
        #expect(largeConfig.k > 0)

        #expect(smallConfig.k > largeConfig.k, "Small graphs should have larger k (more spacing)")
    }
}
