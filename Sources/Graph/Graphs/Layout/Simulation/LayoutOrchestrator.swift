//
//  LayoutOrchestrator.swift
//  MatrixStuff
//
//  Primary simulation controller for force-directed graph layout.
//

import Matrix
import Foundation
import Matrix
import Observation
#if os(iOS)
import Matrix
import UIKit
#elseif os(macOS)
import Matrix
import AppKit
#endif

/// Primary simulation controller for force-directed graph layout.
///
/// Manages the simulation state, physics integration, and convergence detection.
/// Observable properties trigger SwiftUI updates automatically — SwiftUI refreshes
/// a view only when a property the view's `body` reads actually changes.
@MainActor
@Observable
public class LayoutOrchestrator {
    // MARK: - Observable State

    /// Whether the simulation is currently running.
    public var isRunning: Bool = false

    /// Whether the simulation has settled (converged).
    public var isSettled: Bool = false

    /// Current iteration count.
    public var iteration: Int = 0

    /// Current temperature (for simulated annealing).
    public var temperature: Float = 0.0

    /// Current kinetic energy (for monitoring).
    public var kineticEnergy: Float = 0.0

    // MARK: - Internal State

    /// Layout state (positions, velocities, etc.).
    public var state: LayoutState

    /// Edge activation states.
    public var edgeStates: EdgeStateManager

    /// Graph topology.
    public let graph: Graph

    /// Configuration parameters.
    public var config: LayoutConfiguration

    /// Settle detector for convergence checking.
    @ObservationIgnored private var settleDetector: SettleDetector

    /// Timer for macOS or display link callback storage.
    @ObservationIgnored private var timer: Timer?

    // MARK: - Callbacks

    /// Called when simulation settles.
    public var onSettled: (() -> Void)?

    /// Called when simulation resumes from settled state.
    public var onResumed: (() -> Void)?

    /// Called after each simulation step.
    public var onStep: (() -> Void)?

    // MARK: - Initialization

    /// Creates a new layout orchestrator.
    ///
    /// - Parameters:
    ///   - graph: The graph to layout
    ///   - config: Configuration parameters
    public init(graph: Graph, config: LayoutConfiguration = .default) {
        self.graph = graph
        self.config = config
        self.state = LayoutState(nodeCount: graph.nodes.count)
        self.edgeStates = EdgeStateManager(edgeCount: graph.edges.count)
        self.temperature = Float(config.initialTemperature)
        self.settleDetector = SettleDetector(
            threshold: config.settleThreshold,
            requiredFrames: config.settleFrameCount
        )

        // Initialize positions randomly
        state.randomizePositions(radius: 500, mode2D: config.mode2D)
    }

    // MARK: - Control

    /// Starts the simulation.
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        startTimer()
    }

    /// Stops the simulation.
    public func stop() {
        isRunning = false
        stopTimer()
    }

    /// Resumes the simulation from a settled state.
    public func resume() {
        isSettled = false
        settleDetector.reset()
        if !isRunning {
            start()
        }
        onResumed?()
    }

    /// Resets the simulation to initial state.
    public func reset() {
        stop()
        state.randomizePositions(radius: 500, mode2D: config.mode2D)
        state.resetVelocities()
        temperature = Float(config.initialTemperature)
        iteration = 0
        isSettled = false
        settleDetector.reset()
    }

    // MARK: - Simulation Step

    /// Performs one simulation step.
    public func step() {
        // Compute forces
        let forces = computeForces(
            state: state,
            graph: graph,
            edgeStates: edgeStates,
            config: config
        )

        // Integrate physics
        integrate(
            state: &state,
            forces: forces,
            config: config,
            temperature: temperature
        )

        // Update edge activations
        edgeStates.updateAll(deltaTime: Float(config.deltaTime))

        // Update temperature
        temperature = updateTemperature(current: temperature, config: config)

        // Update kinetic energy
        kineticEnergy = state.kineticEnergy

        // Increment iteration
        iteration += 1

        // Check settle
        if config.autoSettle && !isSettled {
            isSettled = settleDetector.update(kineticEnergy: kineticEnergy)
            if isSettled {
                stop()
                onSettled?()
            }
        }

        // Notify step completion
        onStep?()
    }

    // MARK: - Edge Transitions

    /// Transitions to a new edge set with smooth activation ramping.
    ///
    /// - Parameters:
    ///   - newEdges: New edge array
    ///   - duration: Ramp duration in seconds (default: 0.5)
    ///   - velocityRetain: Fraction of velocity to keep (default: 0.5)
    public func transitionToEdgeSet(
        newEdges: [Edge],
        duration: Float = 0.5,
        velocityRetain: Float = 0.5
    ) {
        // Note: This is a simplified implementation.
        // A full implementation would fade out old edges not in the new set.

        // Replace edge states
        edgeStates = EdgeStateManager(edgeCount: newEdges.count, initialAlpha: 0.0)

        // Fade in new edges
        edgeStates.rampAll(to: 1.0, duration: duration)

        // Reduce velocities to dampen chaos
        state.scaleVelocities(by: velocityRetain)

        // Resume simulation if paused
        if isSettled {
            resume()
        }
    }

    // MARK: - Utilities

    /// Reheats the simulation by boosting temperature.
    ///
    /// - Parameter temperatureBoost: Amount to add to temperature
    public func reheat(temperatureBoost: Float = 200.0) {
        temperature = min(temperature + temperatureBoost, Float(config.initialTemperature))
        resume()
    }

    /// Injects random velocity noise to disturb the system.
    ///
    /// - Parameter magnitude: Magnitude of random velocity
    public func injectVelocityNoise(magnitude: Float = 50.0) {
        for i in 0..<state.nodeCount {
            state.velocities[i] += SIMD3<Float>(
                Float.random(in: -magnitude...magnitude),
                Float.random(in: -magnitude...magnitude),
                config.mode2D ? 0 : Float.random(in: -magnitude...magnitude)
            )
        }
        resume()
    }

    /// Pins a node at the specified position.
    ///
    /// - Parameters:
    ///   - nodeIndex: Index of node to pin
    ///   - position: Target position
    public func pinNode(at nodeIndex: Int, position: SIMD3<Float>) {
        guard nodeIndex >= 0 && nodeIndex < state.nodeCount else { return }
        state.pinned[nodeIndex] = true
        state.pinnedTargets[nodeIndex] = position
        resume()
    }

    /// Unpins a node.
    ///
    /// - Parameter nodeIndex: Index of node to unpin
    public func unpinNode(at nodeIndex: Int) {
        guard nodeIndex >= 0 && nodeIndex < state.nodeCount else { return }
        state.pinned[nodeIndex] = false
    }

    // MARK: - Timer Management

    private func startTimer() {
        #if os(macOS)
        timer = Timer.scheduledTimer(withTimeInterval: config.deltaTime, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.step()
            }
        }
        #elseif os(iOS)
        // For iOS, we'd use CADisplayLink, but for now use Timer
        timer = Timer.scheduledTimer(withTimeInterval: config.deltaTime, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.step()
            }
        }
        #endif
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Deinitialization

    nonisolated deinit {
        // Timer cleanup happens automatically when the object is deallocated
        // No need to explicitly call stopTimer() in deinit
    }
}
