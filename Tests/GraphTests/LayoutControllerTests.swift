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
//  LayoutControllerTests.swift
//  MatrixStuffTests
//
//  Tests for the @Observable layout controllers (LayoutOrchestrator drives
//  GraphLayoutView). Methods are exercised directly via step() rather than the
//  animation timer, so the tests stay deterministic.
//

import Testing
import Foundation
import simd
@testable import Graph

@MainActor
@Suite("Layout Controllers")
struct LayoutControllerTests {

    // MARK: - LayoutOrchestrator

    @Test func orchestratorInitialState() {
        let g = Graph.smallGraph
        let o = LayoutOrchestrator(graph: g)

        #expect(o.isRunning == false)
        #expect(o.isSettled == false)
        #expect(o.iteration == 0)
        #expect(o.state.nodeCount == g.nodes.count)
        #expect(o.edgeStates.states.count == g.edges.count)
        #expect(o.temperature == Float(o.config.initialTemperature))
    }

    @Test func orchestratorStepAdvancesState() {
        let o = LayoutOrchestrator(graph: Graph.smallGraph)
        let startTemp = o.temperature

        o.step()

        #expect(o.iteration == 1)
        #expect(o.temperature < startTemp, "Cooling reduces temperature each step")
    }

    @Test func orchestratorResetRestoresInitialState() {
        let o = LayoutOrchestrator(graph: Graph.smallGraph)
        for _ in 0..<5 { o.step() }
        #expect(o.iteration == 5)

        o.reset()

        #expect(o.iteration == 0)
        #expect(o.isSettled == false)
        #expect(o.temperature == Float(o.config.initialTemperature))
    }

    @Test func orchestratorPinnedNodeHoldsPosition() {
        let o = LayoutOrchestrator(graph: Graph.smallGraph)
        let target = SIMD3<Float>(42, -7, 0)

        o.pinNode(at: 0, position: target)
        o.stop()   // cancel the animation timer that resume() started
        #expect(o.state.pinned[0] == true)

        o.step()
        #expect(o.state.positions[0] == target, "A pinned node stays at its target through a step")

        o.unpinNode(at: 0)
        #expect(o.state.pinned[0] == false)
    }

    @Test func orchestratorReheatRaisesAndCapsTemperature() {
        let o = LayoutOrchestrator(graph: Graph.smallGraph)
        for _ in 0..<50 { o.step() }
        let cooled = o.temperature

        o.reheat(temperatureBoost: 100.0)
        o.stop()   // cancel the timer started by reheat → resume

        #expect(o.temperature > cooled, "Reheat raises temperature")
        #expect(o.temperature <= Float(o.config.initialTemperature), "Reheat is capped at the initial temperature")
    }

    @Test func orchestratorPinIgnoresOutOfRangeIndex() {
        let o = LayoutOrchestrator(graph: Graph.smallGraph)
        // Out-of-range indices are guarded no-ops (must not crash).
        o.pinNode(at: 999, position: .zero)
        o.unpinNode(at: -1)
        #expect(o.state.pinned.allSatisfy { $0 == false })
    }

    // MARK: - Settle detection

    /// Regression: settle detection used to watch raw kinetic energy, which on a
    /// real distance-weighted graph levels off near 1e5 (unresolvable edge
    /// tension) while annealing has already frozen the picture, so `isSettled`
    /// never fired. It now watches the largest visible per-node move.
    @Test("Real distance-weighted graphs settle on motion, before the iteration cap",
          arguments: ["default", "largeGraph", "distanceWeighted"])
    func settlesOnMotion(name: String) {
        let config: LayoutConfiguration = switch name {
        case "largeGraph": .largeGraph
        case "distanceWeighted": .distanceWeightedGraph()
        default: .default
        }
        let o = LayoutOrchestrator(graph: Graph.lophoGraph, config: config)
        while !o.isSettled && o.iteration < config.maxIterations + 1 {
            o.step()
        }
        #expect(o.isSettled, "\(name)")
        #expect(o.iteration < config.maxIterations, "\(name) settled by motion, not the cap")
        #expect(o.state.maxDisplacement < config.settleThreshold, "\(name)")
        #expect(o.kineticEnergy > 1, "\(name): raw energy is still far from zero, as expected")
    }

    @Test("maxIterations stops a layout that never goes quiet")
    func iterationCapStops() {
        var config = LayoutConfiguration.default
        config.coolingFactor = 1.0       // never anneals
        config.settleThreshold = 0       // motion check can never pass
        config.maxIterations = 25
        let o = LayoutOrchestrator(graph: Graph.lophoGraph, config: config)
        for _ in 0..<25 { o.step() }
        #expect(o.isSettled)
        #expect(o.iteration == 25)

        // resume() grants a fresh budget rather than settling immediately.
        o.resume()
        o.stop()
        o.step()
        #expect(!o.isSettled)
    }

    @Test("A held node keeps the layout running past the cap")
    func pinnedNodeBlocksSettle() {
        var config = LayoutConfiguration.default
        config.maxIterations = 5
        let o = LayoutOrchestrator(graph: Graph.smallGraph, config: config)
        o.pinNode(at: 0, position: .zero)
        o.stop()
        for _ in 0..<20 { o.step() }
        #expect(!o.isSettled)

        o.unpinNode(at: 0)
        for _ in 0..<20 where !o.isSettled { o.step() }
        #expect(o.isSettled)
    }

    // MARK: - Settle outcome & budget suggestions

    @Test("A budget cut-off while moving is reported, with a budget that reaches rest")
    func cutOffSuggestsBudget() throws {
        var config = LayoutConfiguration.default
        config.maxIterations = 200
        let o = LayoutOrchestrator(graph: Graph.lophoGraph, config: config)
        while !o.isSettled { o.step() }

        guard case .stoppedStillMoving(let motion, let suggested?) = o.settleOutcome else {
            Issue.record("expected a still-moving cut-off with a suggestion, got \(String(describing: o.settleOutcome))")
            return
        }
        #expect(motion >= config.settleThreshold)
        #expect(suggested > 200)

        o.continueRun(toBudget: suggested)
        o.stop()
        #expect(o.iterationBudget == suggested)
        while !o.isSettled { o.step() }
        #expect(o.settleOutcome == .atRest)
        #expect(o.iteration <= suggested)
    }

    @Test("Settling by motion reports at rest")
    func restingOutcome() {
        let o = LayoutOrchestrator(graph: Graph.lophoGraph, config: .distanceWeightedGraph())
        while !o.isSettled { o.step() }
        #expect(o.settleOutcome == .atRest)
        o.resume()
        o.stop()
        #expect(o.settleOutcome == nil)
    }

    @Test("iterationBudget edits the active algorithm's budget")
    func iterationBudgetFollowsAlgorithm() {
        let o = LayoutOrchestrator(graph: Graph.smallGraph)
        o.iterationBudget = 1234
        #expect(o.config.maxIterations == 1234)
        o.setAlgorithm(.kamadaKawai)
        o.stop()
        #expect(o.iterationBudget == 50)
        o.iterationBudget = 80
        #expect(o.config.kamadaKawaiMovesPerNode == 80)
        #expect(o.config.maxIterations == 1234)
    }

    // MARK: - MotionTrend

    @Test("MotionTrend recovers the frames left in a geometric decay")
    func motionTrendGeometric() throws {
        var trend = MotionTrend(window: 30)
        let rate: Float = 0.95
        var motion: Float = 10
        for _ in 0..<30 { trend.record(motion); motion *= rate }
        let last = 10 * pow(rate, 29)
        let exact = log(0.05 / last) / log(rate)
        let estimate = try #require(trend.framesToRest(threshold: 0.05))
        #expect(abs(Float(estimate) - exact) <= 3, "estimate \(estimate) vs exact \(exact)")
    }

    @Test("MotionTrend gives no estimate when motion is not decaying")
    func motionTrendFlat() {
        var trend = MotionTrend()
        for i in 0..<30 { trend.record(i.isMultiple(of: 2) ? 1.0 : 1.2) }
        #expect(trend.framesToRest(threshold: 0.05) == nil)
    }

    @Test("MotionTrend needs some history, and reports zero once below threshold")
    func motionTrendEdges() {
        var trend = MotionTrend()
        for _ in 0..<5 { trend.record(1) }
        #expect(trend.framesToRest(threshold: 0.05) == nil)
        for _ in 0..<10 { trend.record(0.01) }
        #expect(trend.framesToRest(threshold: 0.05) == 0)
    }
}
