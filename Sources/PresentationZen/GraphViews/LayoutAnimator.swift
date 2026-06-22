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
//  LayoutAnimator.swift
//  MatrixStuff
//
//  SwiftUI bridge for animating force-directed layouts.
//

import Graph
import SwiftUI
import Graph
import Observation

#if os(iOS)
import Graph
import UIKit
#elseif os(macOS)
import Graph
import AppKit
#endif

/// SwiftUI-compatible animator for force-directed graph layouts.
///
/// Bridges the imperative physics simulation with SwiftUI's declarative paradigm.
/// Manages the animation loop (CADisplayLink on iOS, Timer on macOS) and publishes
/// updates to trigger view refreshes.
///
/// ## Usage
///
/// ```swift
/// struct MyGraphView: View {
///     @State private var animator = LayoutAnimator(
///         graph: Graph.smallGraph,
///         configuration: LayoutConfiguration()
///     )
///
///     var body: some View {
///         VStack {
///             GraphLayoutView(animator: animator)
///
///             Button(animator.isAnimating ? "Pause" : "Start") {
///                 animator.isAnimating ? animator.stop() : animator.start()
///             }
///         }
///         .onAppear {
///             animator.start()
///         }
///     }
/// }
/// ```
///
/// ## Animation Lifecycle
///
/// 1. Create animator with graph and configuration
/// 2. Call `start()` to begin animation loop
/// 3. Animator calls `simulation.step()` at 60 FPS
/// 4. SwiftUI views update automatically via observable properties
/// 5. Call `stop()` to pause, `reset()` to restart from random positions
@MainActor
@Observable
public class LayoutAnimator {

    // MARK: - Observable Properties

    /// The graph being laid out (publishes changes for SwiftUI).
    public var graph: Graph

    /// Whether the animation is currently running.
    public var isAnimating: Bool = false

    /// Current iteration number.
    public var iteration: Int = 0

    /// Current temperature value.
    public var temperature: Double = 0.0

    /// Whether the layout has converged.
    public var hasConverged: Bool = false

    // MARK: - Private Properties

    /// The physics simulation engine.
    @ObservationIgnored private var simulation: LayoutSimulation?

    /// Platform-specific animation timer (iOS).
    #if os(iOS)
    @ObservationIgnored private var displayLink: CADisplayLink?
    #endif

    /// Platform-specific animation timer (macOS).
    #if os(macOS)
    @ObservationIgnored private var timer: Timer?
    #endif

    // MARK: - Initialization

    /// Creates a new layout animator.
    ///
    /// - Parameters:
    ///   - graph: The graph to animate
    ///   - configuration: Layout algorithm parameters
    ///
    /// The graph should have `layoutCoordinate` values initialized before starting
    /// the animation. Call `graph.initializeRandomLayout(in:)` if needed.
    ///
    /// ## Example
    /// ```swift
    /// let graph = Graph.smallGraph
    /// graph.initializeRandomLayout(in: CGRect(x: 0, y: 0, width: 500, height: 500))
    ///
    /// let animator = LayoutAnimator(
    ///     graph: graph,
    ///     configuration: LayoutConfiguration.smallGraph
    /// )
    /// ```
    public init(graph: Graph, configuration: LayoutConfiguration = LayoutConfiguration()) {
        self.graph = graph
        self.simulation = LayoutSimulation(graph: graph, configuration: configuration)
        self.temperature = configuration.initialTemperature

        // Set up simulation callbacks
        simulation?.onUpdate = { [weak self] _, temp in
            self?.temperature = temp  // Observable assignment triggers SwiftUI refresh
        }

        simulation?.onIteration = { [weak self] iter, _ in
            self?.iteration = iter
        }

        simulation?.onConverged = { [weak self] in
            self?.hasConverged = true
            self?.stop()
        }
    }

    // MARK: - Animation Control

    /// Starts the animation loop.
    ///
    /// Begins calling `simulation.step()` at ~60 FPS using platform-specific timers.
    /// On iOS, uses CADisplayLink for smooth animation. On macOS, uses Timer.
    ///
    /// Does nothing if animation is already running.
    ///
    /// ## Example
    /// ```swift
    /// animator.start()
    /// // Animation runs until converged or manually stopped
    /// ```
    public func start() {
        guard !isAnimating else { return }
        isAnimating = true

        #if os(iOS)
        displayLink = CADisplayLink(target: self, selector: #selector(animationStep))
        displayLink?.add(to: .main, forMode: .common)
        #else
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.animationStep()
            }
        }
        #endif
    }

    /// Stops the animation loop.
    ///
    /// Pauses the simulation without resetting state. Call `start()` to resume.
    ///
    /// ## Example
    /// ```swift
    /// animator.stop()
    /// // Animation paused, state preserved
    /// animator.start()  // Resume from current state
    /// ```
    public func stop() {
        isAnimating = false

        #if os(iOS)
        displayLink?.invalidate()
        displayLink = nil
        #else
        timer?.invalidate()
        timer = nil
        #endif
    }

    /// Resets the simulation and randomizes node positions.
    ///
    /// Stops animation, resets simulation state, and reinitializes nodes to random positions.
    /// After calling reset(), call `start()` to begin a fresh simulation.
    ///
    /// ## Example
    /// ```swift
    /// animator.reset()
    /// animator.start()  // Start fresh simulation from random positions
    /// ```
    public func reset() {
        stop()
        simulation?.reset()
        graph.initializeRandomLayout(in: simulation?.configuration.bounds ?? CGRect(x: 0, y: 0, width: 500, height: 500))
        iteration = 0
        temperature = simulation?.configuration.initialTemperature ?? 100.0
        hasConverged = false
    }

    // MARK: - Private Methods

    /// Executes one simulation step (called by timer).
    @objc private func animationStep() {
        simulation?.step()
    }

    // MARK: - Public Utilities

    /// Current progress as a percentage (0.0 to 1.0).
    public var progress: Double {
        return simulation?.progress ?? 0.0
    }

    /// Average energy in the system (after temperature clamping).
    ///
    /// Useful for monitoring convergence. Value decreases as layout stabilizes.
    public var averageEnergy: Double {
        return simulation?.averageEnergy() ?? 0.0
    }

    /// Average energy before temperature clamping (for diagnostics).
    ///
    /// Shows true force magnitudes even when temperature has dropped to zero.
    /// If this is high but averageEnergy is 0, temperature is suppressing forces.
    public var unclampedEnergy: Double {
        return simulation?.unclampedEnergy() ?? 0.0
    }

    /// Updates the configuration and restarts if currently animating.
    ///
    /// - Parameter newConfiguration: The new configuration to apply
    ///
    /// ## Example
    /// ```swift
    /// var config = LayoutConfiguration.largeGraph
    /// config.k = 200.0
    /// animator.updateConfiguration(config)
    /// ```
    public func updateConfiguration(_ newConfiguration: LayoutConfiguration) {
        let wasAnimating = isAnimating
        stop()

        simulation = LayoutSimulation(graph: graph, configuration: newConfiguration)
        temperature = newConfiguration.initialTemperature

        // Reconnect callbacks
        simulation?.onUpdate = { [weak self] _, temp in
            self?.temperature = temp  // Observable assignment triggers SwiftUI refresh
        }

        simulation?.onIteration = { [weak self] iter, _ in
            self?.iteration = iter
        }

        simulation?.onConverged = { [weak self] in
            self?.hasConverged = true
            self?.stop()
        }

        if wasAnimating {
            start()
        }
    }

    /// Updates the repulsion strength without restarting the simulation.
    ///
    /// This allows real-time tuning of repulsive forces while the layout is running.
    ///
    /// - Parameter strength: The new repulsion strength multiplier
    public func updateRepulsionStrength(_ strength: Double) {
        simulation?.configuration.repulsionStrength = strength
    }

    /// Updates the attraction (spring) strength without restarting the simulation.
    ///
    /// This allows real-time tuning of edge spring forces while the layout is running.
    ///
    /// - Parameter strength: The new attraction strength multiplier
    public func updateAttractionStrength(_ strength: Double) {
        simulation?.configuration.attractionStrength = strength
    }

    /// Updates the center gravity without restarting the simulation.
    ///
    /// This allows real-time tuning of the pull toward center while the layout is running.
    ///
    /// - Parameter gravity: The new center gravity strength
    public func updateCenterGravity(_ gravity: Double) {
        simulation?.configuration.centerGravity = gravity
    }
}
