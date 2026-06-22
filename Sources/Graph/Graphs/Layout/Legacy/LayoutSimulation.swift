//
//  LayoutSimulation.swift
//  MatrixStuff
//
//  Physics simulation engine for force-directed graph layout.
//

import Matrix
import Foundation

#if os(iOS)
import Matrix
import UIKit
#else
import Matrix
import AppKit
#endif

/// Callback invoked when layout positions are updated.
///
/// - Parameters:
///   - graph: The graph with updated node positions
///   - temperature: Current temperature value
public typealias LayoutUpdateCallback = (Graph, Double) -> Void

/// Physics simulation engine for force-directed graph layout.
///
/// Manages the iterative simulation process, including velocity integration,
/// cooling schedule, and convergence detection. Uses the Fruchterman-Reingold
/// algorithm to compute forces at each step.
///
/// ## Usage Pattern
///
/// ```swift
/// // Create simulation
/// let graph = Graph.smallGraph
/// graph.initializeRandomLayout(in: CGRect(x: 0, y: 0, width: 500, height: 500))
///
/// let simulation = LayoutSimulation(graph: graph)
///
/// // Set up callbacks
/// simulation.onUpdate = { graph, temp in
///     print("Temperature: \(temp)")
///     // Redraw UI...
/// }
///
/// simulation.onConverged = {
///     print("Layout converged!")
/// }
///
/// // Run simulation loop
/// while !simulation.hasConverged {
///     simulation.step()
/// }
/// ```
///
/// ## Animation Integration
///
/// For animated layouts, call `step()` from a display link or timer:
///
/// ```swift
/// let displayLink = CADisplayLink(target: self, selector: #selector(simulationStep))
/// displayLink.add(to: .main, forMode: .common)
///
/// @objc func simulationStep() {
///     simulation.step()
/// }
/// ```
public class LayoutSimulation {

    // MARK: - Properties

    /// The graph being laid out.
    public let graph: Graph

    /// Configuration parameters for the layout algorithm.
    public var configuration: LayoutConfiguration

    /// Current temperature (decreases over time via cooling schedule).
    public private(set) var temperature: Double

    /// Current iteration number.
    public private(set) var iteration: Int = 0

    /// Whether the simulation has converged to a stable state.
    public private(set) var hasConverged: Bool = false

    // MARK: - Callbacks

    /// Called after each simulation step with updated graph and temperature.
    public var onUpdate: LayoutUpdateCallback?

    /// Called when the layout converges to a stable configuration.
    public var onConverged: (() -> Void)?

    /// Called at the end of each iteration with iteration number and temperature.
    public var onIteration: ((Int, Double) -> Void)?

    // MARK: - Private State

    /// Per-node velocities for momentum-based movement.
    private var velocities: [UUID: CGVector] = [:]

    // MARK: - Initialization

    /// Creates a new layout simulation.
    ///
    /// - Parameters:
    ///   - graph: The graph to lay out
    ///   - configuration: Layout parameters (default: standard configuration)
    ///
    /// ## Example
    /// ```swift
    /// let config = LayoutConfiguration(bounds: CGRect(x: 0, y: 0, width: 800, height: 600))
    /// config.k = 150.0
    /// config.coolingFactor = 0.98
    ///
    /// let simulation = LayoutSimulation(graph: graph, configuration: config)
    /// ```
    public init(graph: Graph, configuration: LayoutConfiguration = LayoutConfiguration()) {
        self.graph = graph
        self.configuration = configuration
        self.temperature = configuration.initialTemperature

        // Initialize velocities to zero
        for node in graph.nodes {
            velocities[node.id] = .zero
        }
    }

    // MARK: - Simulation Control

    /// Executes a single simulation step.
    ///
    /// Computes forces, updates velocities and positions, applies cooling, and checks for convergence.
    /// This method should be called repeatedly (e.g., from a timer) for animated layouts.
    ///
    /// ## Process
    /// 1. Compute all forces (repulsive + attractive + center gravity)
    /// 2. Add collision forces (prevent node overlap)
    /// 3. Add boundary forces (soft walls)
    /// 4. Update node velocities and positions (with temperature scaling)
    /// 5. Decrease temperature (cooling schedule)
    /// 6. Check for convergence
    /// 7. Invoke callbacks
    ///
    /// ## Example
    /// ```swift
    /// // Run to convergence
    /// while !simulation.hasConverged {
    ///     simulation.step()
    /// }
    ///
    /// // Or run fixed iterations
    /// for _ in 0..<100 {
    ///     simulation.step()
    /// }
    /// ```
    public func step() {
        guard !hasConverged else { return }

        // STEP 1: Compute all forces
        var forces = ForceDirectedLayout.computeForces(
            graph: graph,
            k: configuration.k,
            repulsionStrength: configuration.repulsionStrength,
            attractionStrength: configuration.attractionStrength,
            centerGravity: configuration.centerGravity,
            bounds: configuration.bounds
        )

        // STEP 2: Add collision forces if enabled
        if configuration.useCollisionDetection {
            ForceDirectedLayout.addCollisionForces(
                forces: &forces,
                graph: graph,
                strength: configuration.collisionForceStrength,
                nodeSizeMultiplier: 10.0  // Match GraphLayoutView default
            )
        }

        // STEP 3: Add boundary forces if enabled
        if configuration.useBoundaryForces {
            ForceDirectedLayout.addBoundaryForces(
                forces: &forces,
                graph: graph,
                bounds: configuration.bounds,
                strength: configuration.boundaryForceStrength
            )
        }

        // STEP 4: Update velocities and positions
        updatePositions(forces: forces)

        // STEP 5: Update temperature (cooling schedule)
        temperature = ForceDirectedLayout.updateTemperature(
            current: temperature,
            coolingFactor: configuration.coolingFactor
        )

        iteration += 1

        // STEP 6: Check convergence
        if checkConvergence(forces: forces) || iteration >= configuration.maxIterations {
            hasConverged = true
            onConverged?()
        }

        // STEP 7: Notify observers
        onUpdate?(graph, temperature)
        onIteration?(iteration, temperature)
    }

    /// Resets the simulation to initial state.
    ///
    /// Clears velocities, resets temperature and iteration count, and marks as not converged.
    /// Does NOT reinitialize node positions - call `graph.initializeRandomLayout()` for that.
    ///
    /// ## Example
    /// ```swift
    /// simulation.reset()
    /// graph.initializeRandomLayout(in: bounds)
    /// // Now ready to run again
    /// ```
    public func reset() {
        iteration = 0
        temperature = configuration.initialTemperature
        hasConverged = false
        velocities = [:]

        for node in graph.nodes {
            velocities[node.id] = .zero
        }
    }

    // MARK: - Private Methods

    /// Updates node positions using computed forces.
    ///
    /// Uses velocity Verlet integration with damping for stable, smooth movement.
    /// Temperature is applied as a velocity multiplier (like D3), not force clamping.
    ///
    /// Algorithm:
    /// 1. Update velocity: `v = (v + F × dt) × damping`
    /// 2. Apply temperature scaling to velocity
    /// 3. Update position: `p = p + v × dt × temperature_factor`
    ///
    /// - Parameter forces: Dictionary of forces acting on each node
    private func updatePositions(forces: [UUID: CGVector]) {
        // Normalize temperature to a 0-1 range for velocity scaling
        let temperatureFactor = min(1.0, temperature / configuration.initialTemperature)

        for node in graph.nodes {
            guard let force = forces[node.id],
                  let currentPos = node.layoutCoordinate else { continue }

            // Update velocity with damping (simulates friction)
            var velocity = velocities[node.id] ?? .zero
            velocity.dx = (velocity.dx + force.dx * configuration.deltaTime) * configuration.damping
            velocity.dy = (velocity.dy + force.dy * configuration.deltaTime) * configuration.damping
            velocities[node.id] = velocity

            // Apply temperature scaling to velocity (simulated annealing)
            // High temperature = large movements, low temperature = small adjustments
            let scaledVelocity = CGVector(
                dx: velocity.dx * temperatureFactor,
                dy: velocity.dy * temperatureFactor
            )

            // Update position using temperature-scaled velocity
            let newPos = CGPoint(
                x: currentPos.x + scaledVelocity.dx * configuration.deltaTime,
                y: currentPos.y + scaledVelocity.dy * configuration.deltaTime
            )
            node.layoutCoordinate = newPos
        }
    }

    /// Checks whether the layout has converged to a stable state.
    ///
    /// Convergence is determined by average force magnitude falling below the threshold.
    /// When the system has low energy (small forces), nodes are near equilibrium.
    ///
    /// - Parameter forces: Dictionary of forces acting on each node
    /// - Returns: `true` if converged, `false` otherwise
    private func checkConvergence(forces: [UUID: CGVector]) -> Bool {
        guard !forces.isEmpty else { return true }

        // Compute total energy in the system
        let totalEnergy = forces.values.reduce(0.0) { sum, force in
            sum + hypot(force.dx, force.dy)
        }

        // Average energy per node
        let avgEnergy = totalEnergy / Double(forces.count)

        return avgEnergy < configuration.convergenceThreshold
    }

    // MARK: - Public Utilities

    /// Current total energy in the system (sum of force magnitudes).
    ///
    /// Useful for monitoring convergence progress.
    ///
    /// - Returns: Total force magnitude across all nodes
    public func totalEnergy() -> Double {
        let forces = ForceDirectedLayout.computeForces(
            graph: graph,
            k: configuration.k,
            repulsionStrength: configuration.repulsionStrength,
            attractionStrength: configuration.attractionStrength,
            centerGravity: configuration.centerGravity,
            bounds: configuration.bounds
        )

        return forces.values.reduce(0.0) { sum, force in
            sum + hypot(force.dx, force.dy)
        }
    }

    /// Average energy per node.
    ///
    /// - Returns: Average force magnitude per node
    public func averageEnergy() -> Double {
        guard graph.cardinality > 0 else { return 0 }
        return totalEnergy() / Double(graph.cardinality)
    }

    /// Raw force energy without temperature scaling applied to velocity.
    ///
    /// Shows the actual force magnitudes before temperature affects movement.
    /// Since temperature is now applied to velocity rather than clamping forces,
    /// this is essentially the same as totalEnergy() but kept for diagnostic purposes.
    ///
    /// - Returns: Average force magnitude per node
    public func unclampedEnergy() -> Double {
        return averageEnergy()
    }

    /// Progress towards max iterations (0.0 to 1.0).
    ///
    /// - Returns: Fraction of max iterations completed
    public var progress: Double {
        guard configuration.maxIterations > 0 else { return 1.0 }
        return Double(iteration) / Double(configuration.maxIterations)
    }
}
