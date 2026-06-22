//
//  ForceDirectedLayout.swift
//  MatrixStuff
//
//  Fruchterman-Reingold force-directed graph layout algorithm.
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

/// Fruchterman-Reingold force-directed layout algorithm.
///
/// Implements the classic force-directed graph drawing algorithm that treats edges as springs
/// and nodes as repelling particles. The algorithm iteratively adjusts node positions to
/// minimize energy and create aesthetically pleasing layouts.
///
/// ## Algorithm Overview
///
/// 1. **Repulsive forces** between all node pairs push nodes apart
/// 2. **Attractive forces** along edges pull connected nodes together
/// 3. **Edge weights** determine ideal spring lengths
/// 4. **Temperature** controls the magnitude of movements (decreases over time)
///
/// ## Force Equations
///
/// - Repulsive force: `F_r = k² / d`
/// - Attractive force: `F_a = (d - idealLength)² / k`
/// - Ideal length: `edge.weight × k`
///
/// ## Example
/// ```swift
/// let graph = Graph.smallGraph
/// graph.initializeRandomLayout(in: CGRect(x: 0, y: 0, width: 500, height: 500))
///
/// let forces = ForceDirectedLayout.computeForces(
///     graph: graph,
///     k: 100.0,
///     temperature: 50.0
/// )
/// ```
///
/// ## References
/// - Fruchterman, T. M. J., & Reingold, E. M. (1991). Graph drawing by force-directed placement.
///   Software: Practice and Experience, 21(11), 1129-1164.
public struct ForceDirectedLayout {

    // MARK: - Force Calculations

    /// Computes repulsive force between two nodes.
    ///
    /// All node pairs experience repulsion, pushing them apart like charged particles.
    /// Uses inverse square law (more physically accurate) for better stability.
    ///
    /// - Parameters:
    ///   - k: Ideal spring length parameter
    ///   - distance: Current distance between nodes
    /// - Returns: Magnitude of repulsive force
    ///
    /// Formula: `F_r = k² / d²` (inverse square law)
    public static func repulsiveForce(k: Double, distance: Double) -> Double {
        guard distance > 0.01 else { return 10000.0 }  // Cap force at very small distances
        return (k * k) / (distance * distance)
    }

    /// Computes attractive force along an edge.
    ///
    /// Connected nodes are pulled together like springs using Hooke's law.
    /// Force is proportional to displacement from ideal length (linear spring model).
    ///
    /// - Parameters:
    ///   - k: Spring stiffness parameter (strength multiplier)
    ///   - distance: Current distance between connected nodes
    ///   - idealLength: Desired spring length (typically `edge.weight × k`)
    /// - Returns: Magnitude of attractive force (positive = pull together, negative = push apart)
    ///
    /// Formula: `F_a = (d - idealLength)` (Hooke's law, F = -kx simplified)
    public static func attractiveForce(k: Double, distance: Double, idealLength: Double) -> Double {
        return distance - idealLength
    }

    /// Computes center gravity force to prevent nodes from drifting to edges.
    ///
    /// Pulls all nodes toward the center of the bounds with a weak force.
    /// Prevents the common issue where repulsion pushes everything to the edges.
    ///
    /// - Parameters:
    ///   - position: Current node position
    ///   - center: Center point of the layout bounds
    ///   - strength: Gravity strength multiplier (typically 0.1 to 1.0)
    /// - Returns: Force vector pointing toward center
    ///
    /// Formula: `F_g = (center - position) × strength`
    public static func centerGravityForce(position: CGPoint, center: CGPoint, strength: Double) -> CGVector {
        let dx = center.x - position.x
        let dy = center.y - position.y
        return CGVector(dx: dx * strength, dy: dy * strength)
    }

    /// Adds collision forces to prevent nodes from overlapping.
    ///
    /// When nodes get closer than their combined radii, adds a strong repulsive force
    /// to push them apart. This prevents the visual issue of overlapping nodes.
    ///
    /// - Parameters:
    ///   - forces: Dictionary of current forces (modified in place)
    ///   - graph: The graph being laid out
    ///   - strength: Collision force strength multiplier (default: 10.0)
    ///   - nodeSizeMultiplier: Multiplier for node sizes (matches visualization scaling)
    ///
    /// Formula: When `distance < radius1 + radius2`, add strong repulsive force
    public static func addCollisionForces(
        forces: inout [UUID: CGVector],
        graph: Graph,
        strength: Double = 10.0,
        nodeSizeMultiplier: Double = 10.0
    ) {
        for i in 0..<graph.nodes.count {
            for j in (i+1)..<graph.nodes.count {
                let node1 = graph.nodes[i]
                let node2 = graph.nodes[j]

                guard let pos1 = node1.layoutCoordinate,
                      let pos2 = node2.layoutCoordinate,
                      var force1 = forces[node1.id],
                      var force2 = forces[node2.id] else { continue }

                let delta = CGPoint(x: pos1.x - pos2.x, y: pos1.y - pos2.y)
                let distance = hypot(delta.x, delta.y)

                // Calculate combined radius (nodes visualized as circles)
                let radius1 = node1.size * nodeSizeMultiplier / 2
                let radius2 = node2.size * nodeSizeMultiplier / 2
                let minDistance = radius1 + radius2

                // If nodes are overlapping, add strong repulsive force
                if distance < minDistance && distance > 0.01 {
                    let overlap = minDistance - distance
                    let force = overlap * strength
                    let unitVector = CGVector(dx: delta.x/distance, dy: delta.y/distance)

                    force1.dx += unitVector.dx * force
                    force1.dy += unitVector.dy * force
                    force2.dx -= unitVector.dx * force
                    force2.dy -= unitVector.dy * force

                    forces[node1.id] = force1
                    forces[node2.id] = force2
                }
            }
        }
    }

    /// Computes all forces acting on nodes for the current iteration.
    ///
    /// This is the core of the algorithm, computing repulsive forces between all
    /// node pairs, attractive forces along edges, and center gravity.
    ///
    /// - Parameters:
    ///   - graph: The graph to compute forces for
    ///   - k: Ideal spring length parameter
    ///   - repulsionStrength: Multiplier for repulsive force strength (default: 1.0)
    ///   - attractionStrength: Multiplier for attractive (spring) force strength (default: 1.0)
    ///   - centerGravity: Strength of pull toward center (0.0 = off, typical: 0.1-1.0)
    ///   - bounds: Layout bounds (for center calculation)
    /// - Returns: Dictionary mapping node UUIDs to force vectors
    ///
    /// ## Complexity
    /// - Time: O(n² + m) where n = nodes, m = edges
    /// - The O(n²) comes from all-pairs repulsion
    ///
    /// ## Example
    /// ```swift
    /// let forces = ForceDirectedLayout.computeForces(
    ///     graph: graph,
    ///     k: 100.0,
    ///     repulsionStrength: 1.0,
    ///     centerGravity: 0.1,
    ///     bounds: CGRect(x: 0, y: 0, width: 500, height: 500)
    /// )
    ///
    /// for (nodeId, force) in forces {
    ///     print("Node \(nodeId): force = (\(force.dx), \(force.dy))")
    /// }
    /// ```
    public static func computeForces(
        graph: Graph,
        k: Double,
        repulsionStrength: Double = 1.0,
        attractionStrength: Double = 1.0,
        centerGravity: Double = 0.1,
        bounds: CGRect = CGRect(x: 0, y: 0, width: 500, height: 500)
    ) -> [UUID: CGVector] {
        var forces: [UUID: CGVector] = [:]

        // Initialize forces to zero
        for node in graph.nodes {
            forces[node.id] = .zero
        }

        // STEP 1: Compute repulsive forces (all pairs)
        // O(n²) - this is the expensive part
        for i in 0..<graph.nodes.count {
            for j in (i+1)..<graph.nodes.count {
                let node1 = graph.nodes[i]
                let node2 = graph.nodes[j]

                guard let pos1 = node1.layoutCoordinate,
                      let pos2 = node2.layoutCoordinate else { continue }

                // Compute displacement vector
                let delta = CGPoint(x: pos1.x - pos2.x, y: pos1.y - pos2.y)
                let distance = hypot(delta.x, delta.y)

                if distance > 0.01 {  // Avoid division by zero
                    let force = repulsiveForce(k: k, distance: distance) * repulsionStrength
                    let unitVector = CGVector(dx: delta.x/distance, dy: delta.y/distance)

                    // Apply force to both nodes (Newton's third law)
                    forces[node1.id]!.dx += unitVector.dx * force
                    forces[node1.id]!.dy += unitVector.dy * force
                    forces[node2.id]!.dx -= unitVector.dx * force
                    forces[node2.id]!.dy -= unitVector.dy * force
                }
            }
        }

        // STEP 2: Compute attractive forces (along edges)
        // O(m) where m = number of edges
        for edge in graph.edges {
            guard let node1 = graph.node(id: edge.fromNode),
                  let node2 = graph.node(id: edge.toNode),
                  let pos1 = node1.layoutCoordinate,
                  let pos2 = node2.layoutCoordinate else { continue }

            // Compute displacement vector
            let delta = CGPoint(x: pos2.x - pos1.x, y: pos2.y - pos1.y)
            let distance = hypot(delta.x, delta.y)

            // KEY FEATURE: Use edge weight as ideal spring length
            let idealLength = edge.weight * k
            let force = attractiveForce(k: k, distance: distance, idealLength: idealLength) * attractionStrength

            if distance > 0.01 {
                let unitVector = CGVector(dx: delta.x/distance, dy: delta.y/distance)

                // Apply force to both nodes
                forces[node1.id]!.dx += unitVector.dx * force
                forces[node1.id]!.dy += unitVector.dy * force
                forces[node2.id]!.dx -= unitVector.dx * force
                forces[node2.id]!.dy -= unitVector.dy * force
            }
        }

        // STEP 3: Add center gravity forces (prevent drift to edges)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        if centerGravity > 0 {
            for node in graph.nodes {
                guard let pos = node.layoutCoordinate,
                      var force = forces[node.id] else { continue }

                let gravityForce = centerGravityForce(position: pos, center: center, strength: centerGravity)
                force.dx += gravityForce.dx
                force.dy += gravityForce.dy
                forces[node.id] = force
            }
        }

        return forces
    }

    // MARK: - Boundary Constraints

    /// Adds soft boundary forces to keep nodes within bounds.
    ///
    /// Applies repulsive forces from the edges of the bounding rectangle,
    /// creating "invisible walls" that keep nodes on screen.
    ///
    /// - Parameters:
    ///   - forces: Dictionary of current forces (modified in place)
    ///   - graph: The graph being laid out
    ///   - bounds: The bounding rectangle
    ///   - strength: Force strength multiplier
    ///
    /// ## Example
    /// ```swift
    /// var forces = ForceDirectedLayout.computeForces(graph: graph, k: 100, temperature: 50)
    /// ForceDirectedLayout.addBoundaryForces(
    ///     forces: &forces,
    ///     graph: graph,
    ///     bounds: CGRect(x: 0, y: 0, width: 500, height: 500),
    ///     strength: 1000.0
    /// )
    /// ```
    public static func addBoundaryForces(
        forces: inout [UUID: CGVector],
        graph: Graph,
        bounds: CGRect,
        strength: Double
    ) {
        let margin = 50.0  // Distance from boundary where forces start

        for node in graph.nodes {
            guard let pos = node.layoutCoordinate,
                  var force = forces[node.id] else { continue }

            // Left boundary
            if pos.x < bounds.minX + margin {
                let distance = max(0.1, pos.x - bounds.minX)
                force.dx += strength / (distance * distance)
            }

            // Right boundary
            if pos.x > bounds.maxX - margin {
                let distance = max(0.1, bounds.maxX - pos.x)
                force.dx -= strength / (distance * distance)
            }

            // Top boundary
            if pos.y < bounds.minY + margin {
                let distance = max(0.1, pos.y - bounds.minY)
                force.dy += strength / (distance * distance)
            }

            // Bottom boundary
            if pos.y > bounds.maxY - margin {
                let distance = max(0.1, bounds.maxY - pos.y)
                force.dy -= strength / (distance * distance)
            }

            forces[node.id] = force
        }
    }

    // MARK: - Cooling Schedule

    /// Updates temperature for simulated annealing.
    ///
    /// Temperature controls the maximum displacement per iteration.
    /// It decreases over time, allowing the layout to "cool" into a stable configuration.
    ///
    /// - Parameters:
    ///   - current: Current temperature
    ///   - coolingFactor: Multiplier applied each iteration (0.0 to 1.0)
    /// - Returns: New temperature
    ///
    /// Formula: `T_new = T_current × coolingFactor`
    ///
    /// ## Example
    /// ```swift
    /// var temperature = 100.0
    /// for _ in 0..<1000 {
    ///     // ... compute forces and update positions ...
    ///     temperature = ForceDirectedLayout.updateTemperature(
    ///         current: temperature,
    ///         coolingFactor: 0.95
    ///     )
    /// }
    /// ```
    public static func updateTemperature(current: Double, coolingFactor: Double) -> Double {
        return current * coolingFactor
    }

    /// Linear cooling schedule (alternative to exponential).
    ///
    /// Temperature decreases linearly from initial value to zero over max iterations.
    ///
    /// - Parameters:
    ///   - initial: Initial temperature
    ///   - iteration: Current iteration number
    ///   - maxIterations: Maximum number of iterations
    /// - Returns: New temperature
    ///
    /// Formula: `T = T_initial × (1 - iteration / maxIterations)`
    public static func linearCooling(initial: Double, iteration: Int, maxIterations: Int) -> Double {
        let progress = Double(iteration) / Double(maxIterations)
        return initial * (1.0 - progress)
    }
}
