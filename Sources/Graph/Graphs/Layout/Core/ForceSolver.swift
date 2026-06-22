//
//  ForceSolver.swift
//  MatrixStuff
//
//  Force computation for force-directed graph layout.
//  Implements repulsion, attraction, center gravity, collision, and z-flattening forces.
//

import Matrix
import Foundation
import Matrix
import simd

// MARK: - Individual Force Formulas

/// Computes repulsive force between two nodes.
///
/// Formula: F_r = k² / d²  (inverse square law)
///
/// - Parameters:
///   - k: Ideal spring length parameter
///   - distance: Current distance between nodes
///   - strength: Repulsion strength multiplier
/// - Returns: Force magnitude
public func repulsiveForce(k: Float, distance: Float, strength: Float = 1.0) -> Float {
    guard distance > 0.01 else { return 10000.0 }
    return strength * (k * k) / (distance * distance)
}

/// Computes attractive force along an edge (Hooke's law).
///
/// Formula: F_a = (d - L_ideal)
///
/// - Parameters:
///   - distance: Current distance
///   - idealLength: Desired spring length (edge.weight × k)
///   - strength: Attraction strength multiplier
/// - Returns: Force magnitude (positive = pull, negative = push)
public func attractiveForce(distance: Float, idealLength: Float, strength: Float = 1.0) -> Float {
    return strength * (distance - idealLength)
}

/// Pull toward origin to prevent drift.
///
/// Formula: F_gravity = -k_center × position
///
/// - Parameters:
///   - position: Current position
///   - strength: Center gravity strength
/// - Returns: Force vector toward origin
public func centerGravityForce(position: SIMD3<Float>, strength: Float) -> SIMD3<Float> {
    return -position * strength
}

// MARK: - Complete Force Computation

/// Computes all forces acting on nodes.
///
/// Includes:
/// 1. Repulsion (all pairs)
/// 2. Attraction (edges with activation)
/// 3. Center gravity
/// 4. Collision (overlap prevention)
/// 5. Z-flattening (2D mode only)
///
/// - Parameters:
///   - state: Current layout state
///   - graph: Graph topology
///   - edgeStates: Per-edge activation states
///   - config: Configuration parameters
/// - Returns: Array of force vectors (indexed by node index)
public func computeForces(
    state: LayoutState,
    graph: Graph,
    edgeStates: EdgeStateManager,
    config: LayoutConfiguration
) -> [SIMD3<Float>] {

    var forces = Array(repeating: SIMD3<Float>.zero, count: state.nodeCount)

    // 1. Repulsion (all pairs)
    for i in 0..<state.nodeCount {
        for j in (i+1)..<state.nodeCount {
            let delta = state.positions[i] - state.positions[j]
            let distance = simd_length(delta)
            guard distance > 0.01 else { continue }

            let force = repulsiveForce(
                k: Float(config.k),
                distance: distance,
                strength: Float(config.repulsionStrength)
            )
            let direction = simd_normalize(delta)
            forces[i] += direction * force
            forces[j] -= direction * force
        }
    }

    // 2. Attraction (edges with activation)
    for (edgeIndex, edge) in graph.edges.enumerated() {
        guard let fromNode = graph.node(id: edge.fromNode),
              let toNode = graph.node(id: edge.toNode),
              let i = graph.nodes.firstIndex(of: fromNode),
              let j = graph.nodes.firstIndex(of: toNode) else { continue }

        let delta = state.positions[j] - state.positions[i]
        let distance = simd_length(delta)
        let idealLength = Float(edge.weight) * Float(config.k)
        let alpha = edgeStates.states[edgeIndex].alpha
        let force = attractiveForce(
            distance: distance,
            idealLength: idealLength,
            strength: Float(config.attractionStrength) * alpha
        )

        if distance > 0.01 {
            let direction = simd_normalize(delta)
            forces[i] += direction * force
            forces[j] -= direction * force
        }
    }

    // 3. Center gravity
    if config.centerGravity > 0 {
        for i in 0..<state.nodeCount {
            forces[i] += centerGravityForce(
                position: state.positions[i],
                strength: Float(config.centerGravity)
            )
        }
    }

    // 4. Collision
    if config.useCollisionDetection {
        for i in 0..<state.nodeCount {
            for j in (i+1)..<state.nodeCount {
                let delta = state.positions[i] - state.positions[j]
                let distance = simd_length(delta)
                let minDistance = state.radii[i] + state.radii[j]

                if distance < minDistance && distance > 0.01 {
                    let overlap = minDistance - distance
                    let force = overlap * Float(config.collisionForceStrength)
                    let direction = simd_normalize(delta)
                    forces[i] += direction * force
                    forces[j] -= direction * force
                }
            }
        }
    }

    // 5. Z-flattening (2D mode)
    if config.mode2D {
        for i in 0..<state.nodeCount {
            forces[i].z = -state.positions[i].z * config.zFlatteningStrength
        }
    }

    return forces
}
