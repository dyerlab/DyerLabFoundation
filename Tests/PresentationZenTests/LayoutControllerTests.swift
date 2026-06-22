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
import Graph
@testable import PresentationZen

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

    // MARK: - LayoutAnimator

    @Test func animatorInitialState() {
        let a = LayoutAnimator(graph: Graph.smallGraph)

        #expect(a.isAnimating == false)
        #expect(a.iteration == 0)
        #expect(a.hasConverged == false)
        #expect(a.temperature == LayoutConfiguration().initialTemperature)
        #expect(a.progress == 0.0)
    }

    @Test func animatorUpdateConfigurationResetsTemperature() {
        let a = LayoutAnimator(graph: Graph.smallGraph)
        var cfg = LayoutConfiguration()
        cfg.initialTemperature = 123.0

        a.updateConfiguration(cfg)

        #expect(a.temperature == 123.0)
        #expect(a.isAnimating == false, "Updating config on a paused animator leaves it paused")
    }

    @Test func animatorResetRestoresState() {
        let a = LayoutAnimator(graph: Graph.smallGraph)

        a.reset()

        #expect(a.iteration == 0)
        #expect(a.hasConverged == false)
        #expect(a.temperature == LayoutConfiguration().initialTemperature)
    }
}
