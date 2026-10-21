//
//  LayoutOrchestrator.swift
//  DyerLabFoundation
//
//  Primary simulation controller for force-directed graph layout.
//

import Matrix
import Foundation
import Observation
#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
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

    /// How the last run ended; `nil` while running or before the first settle.
    ///
    /// `.stoppedStillMoving` means the budget cut the layout off while parts of
    /// it were still rearranging, and carries a suggested ``iterationBudget``.
    public var settleOutcome: SettleOutcome?

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

    /// Force-directed steps since the last start, reset or resume; capped by
    /// `config.maxIterations`.
    @ObservationIgnored private var runIterations: Int = 0

    /// Timer for macOS or display link callback storage.
    @ObservationIgnored private var timer: Timer?

    /// Kamada–Kawai solver, present while `config.algorithm == .kamadaKawai`.
    @ObservationIgnored private var kamadaKawai: KamadaKawaiSolver?

    /// World units per Kamada–Kawai layout unit.
    @ObservationIgnored private var kamadaKawaiScale: Double = 1

    /// Recent per-frame motion, for estimating how far a cut-off run had to go.
    @ObservationIgnored private var motionTrend = MotionTrend()

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
        if config.algorithm == .kamadaKawai {
            startKamadaKawai()
        }
    }

    // MARK: - Iteration Budget

    /// The active algorithm's run length, in frames: ``LayoutConfiguration/maxIterations``
    /// under Fruchterman–Reingold, ``LayoutConfiguration/kamadaKawaiMovesPerNode``
    /// under Kamada–Kawai (n moves per frame).
    ///
    /// A new value applies from the next start, reset or resume; a run in
    /// progress under Kamada–Kawai keeps the budget it started with.
    public var iterationBudget: Int {
        get {
            switch config.algorithm {
            case .fruchtermanReingold: config.maxIterations
            case .kamadaKawai: config.kamadaKawaiMovesPerNode
            }
        }
        set {
            let value = max(newValue, 1)
            switch config.algorithm {
            case .fruchtermanReingold: config.maxIterations = value
            case .kamadaKawai: config.kamadaKawaiMovesPerNode = value
            }
        }
    }

    /// Kamada–Kawai moves for one run of ``iterationBudget`` frames.
    private var kamadaKawaiMoveBudget: Int {
        max(config.kamadaKawaiMovesPerNode, 1) * max(state.nodeCount, 1)
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
        runIterations = 0
        settleOutcome = nil
        motionTrend.reset()
        kamadaKawai?.extendBudget(kamadaKawaiMoveBudget)
        if !isRunning {
            start()
        }
        onResumed?()
    }

    /// Raises ``iterationBudget`` and carries the current run on to it, as though
    /// it had been started with the larger budget — e.g. to follow a
    /// `.stoppedStillMoving` suggestion without discarding the layout so far.
    ///
    /// Fruchterman–Reingold keeps its temperature and step count, so the result
    /// is the same as one uninterrupted run; Kamada–Kawai takes the remaining
    /// moves, matching `layout_with_kk(maxiter = budget × n)`.
    public func continueRun(toBudget budget: Int) {
        let movesUsed = kamadaKawai?.iteration ?? 0
        iterationBudget = budget
        isSettled = false
        settleOutcome = nil
        settleDetector.reset()
        if config.algorithm == .kamadaKawai {
            kamadaKawai?.extendBudget(max(kamadaKawaiMoveBudget - movesUsed, 0))
        }
        start()
        onResumed?()
    }

    /// Resets the simulation to initial state.
    public func reset() {
        stop()
        state.randomizePositions(radius: 500, mode2D: config.mode2D)
        state.resetVelocities()
        temperature = Float(config.initialTemperature)
        iteration = 0
        runIterations = 0
        isSettled = false
        settleOutcome = nil
        motionTrend.reset()
        settleDetector.reset()
        kamadaKawai = nil
        if config.algorithm == .kamadaKawai {
            startKamadaKawai()
        }
    }

    /// Switches layout algorithm and restarts the layout from scratch.
    ///
    /// Kamada–Kawai restarts from igraph's circle, so the result matches R's
    /// `layout_with_kk()` for the same graph and weighting.
    public func setAlgorithm(_ algorithm: LayoutAlgorithm) {
        guard algorithm != config.algorithm else { return }
        config.algorithm = algorithm
        reset()
        start()
    }

    // MARK: - Simulation Step

    /// Performs one simulation step.
    public func step() {
        switch config.algorithm {
        case .fruchtermanReingold: stepForceDirected()
        case .kamadaKawai: stepKamadaKawai()
        }
    }

    private func stepForceDirected() {
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
        runIterations += 1

        // Check settle: no visible motion, or the iteration cap. Never while a
        // node is held, since stopping would freeze the drag.
        motionTrend.record(state.maxDisplacement)
        let quiet = settleDetector.update(maxDisplacement: state.maxDisplacement)
        if config.autoSettle && !isSettled && !state.pinned.contains(true) {
            if quiet {
                settle(.atRest)
            } else if runIterations >= config.maxIterations {
                settle(outcome(finalMotion: state.maxDisplacement))
            }
        }

        // Notify step completion
        onStep?()
    }

    // MARK: - Kamada–Kawai

    /// Builds the solver from igraph's circle start and sizes it to world units.
    private func startKamadaKawai() {
        let solver: KamadaKawaiSolver
        do {
            solver = try KamadaKawaiSolver(graph: graph, weighting: config.kamadaKawaiWeighting,
                                           maxIterations: kamadaKawaiMoveBudget)
        } catch {
            // Non-positive edge lengths: fall back to hop-count distances.
            solver = try! KamadaKawaiSolver(graph: graph, weighting: .unweighted,
                                            maxIterations: kamadaKawaiMoveBudget)
        }

        // Scale so the mean edge's ideal length is drawn `k` world units long,
        // comparable to Fruchterman–Reingold's spacing for the same config.
        let indices = graph.nodeIndices()
        var total = 0.0
        var count = 0
        for edge in graph.edges {
            guard let i = indices[edge.fromNode], let j = indices[edge.toNode], i != j else { continue }
            total += solver.idealLength(i, j)
            count += 1
        }
        let meanLength = count > 0 ? total / Double(count) : 1
        kamadaKawaiScale = meanLength > 0 ? config.k / meanLength : 1

        kamadaKawai = solver
        temperature = 0
        syncKamadaKawaiPositions()
    }

    /// Advances Kamada–Kawai by one frame's worth of moves (one per node, so a
    /// default 50·n-move run animates over about 50 frames).
    private func stepKamadaKawai() {
        guard kamadaKawai != nil else { return }

        // Dragged nodes are held where the pointer is.
        var anyPinned = false
        for i in 0..<state.nodeCount {
            if state.pinned[i] {
                anyPinned = true
                let target = SIMD2(Double(state.pinnedTargets[i].x),
                                   Double(state.pinnedTargets[i].y)) / kamadaKawaiScale
                kamadaKawai?.fixedPositions[i] = target
                kamadaKawai?.move(i, to: target)
            } else if kamadaKawai?.fixedPositions[i] != nil {
                kamadaKawai?.fixedPositions[i] = nil
            }
        }

        var frameMotion = 0.0
        for _ in 0..<max(state.nodeCount, 1) {
            guard kamadaKawai?.step() == true else { break }
            frameMotion = max(frameMotion, kamadaKawai?.lastMoveDistance ?? 0)
        }
        // Keep relaxing around a node while it is being dragged.
        if anyPinned, kamadaKawai?.isFinished == true {
            kamadaKawai?.extendBudget(kamadaKawaiMoveBudget)
        }

        syncKamadaKawaiPositions()
        kineticEnergy = Float(kamadaKawai?.maxDelta ?? 0)
        let motion = Float(frameMotion * kamadaKawaiScale)
        state.maxDisplacement = motion
        motionTrend.record(motion)
        iteration += 1

        // Kamada–Kawai always runs its full budget, as igraph does; the motion
        // in the final frame says whether it had come to rest.
        if config.autoSettle, !isSettled, kamadaKawai?.isFinished == true {
            settle(motion < config.settleThreshold ? .atRest : outcome(finalMotion: motion))
        }

        onStep?()
    }

    // MARK: - Settling

    private func settle(_ outcome: SettleOutcome) {
        isSettled = true
        settleOutcome = outcome
        stop()
        onSettled?()
    }

    /// Classifies a budget cut-off, suggesting a budget from the motion trend:
    /// the current budget plus the estimated remaining frames, with 25% margin,
    /// rounded up to a tidy number.
    private func outcome(finalMotion: Float) -> SettleOutcome {
        guard finalMotion >= config.settleThreshold else { return .atRest }
        let suggestion = motionTrend.framesToRest(threshold: config.settleThreshold).map { remaining in
            let raw = Double(iterationBudget) + 1.25 * Double(remaining)
            let step = config.algorithm == .kamadaKawai ? 10.0 : 100.0
            return Int((raw / step).rounded(.up) * step)
        }
        return .stoppedStillMoving(maxDisplacement: finalMotion, suggestedBudget: suggestion)
    }

    /// Copies solver positions into `state`, in world units, on the z = 0 plane.
    private func syncKamadaKawaiPositions() {
        guard let solver = kamadaKawai else { return }
        for i in 0..<state.nodeCount {
            let p = solver.position(i) * kamadaKawaiScale
            state.positions[i] = SIMD3(Float(p.x), Float(p.y), 0)
            state.velocities[i] = .zero
        }
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
        // Kamada–Kawai relaxes the rest of the layout around the released node.
        if config.algorithm == .kamadaKawai {
            resume()
        }
    }

    // MARK: - Timer Management

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: config.deltaTime, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.step()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Deinitialization

    nonisolated deinit {
        // Swift 6: nonisolated deinit cannot touch the MainActor-isolated timer.
        // Callers must call stop() before releasing the orchestrator (e.g. in
        // onDisappear) so the timer is invalidated while still on the main actor.
    }
}
