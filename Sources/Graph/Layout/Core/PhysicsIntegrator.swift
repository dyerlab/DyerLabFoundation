//
//  PhysicsIntegrator.swift
//  DyerLabFoundation
//
//  Physics integration for force-directed layout using semi-implicit Euler method.
//

import Matrix
import Foundation
import simd

/// Performs one simulation step using semi-implicit Euler integration.
///
/// Algorithm:
/// 1. Compute forces: F = computeForces(...)
/// 2. Update velocities: v = (v + F/m × dt) × damping
/// 3. Apply temperature scaling: v_scaled = v × temperatureFactor
/// 4. Update positions: p = p + v_scaled × dt
/// 5. Handle pinned nodes (override position & velocity)
///
/// - Parameters:
///   - state: Layout state (modified in-place)
///   - forces: Force vectors from computeForces()
///   - config: Configuration parameters
///   - temperature: Current temperature (0 to initialTemperature)
public func integrate(
    state: inout LayoutState,
    forces: [SIMD3<Float>],
    config: LayoutConfiguration,
    temperature: Float
) {
    let dt = Float(config.deltaTime)
    let damping = Float(config.damping)
    let mass = state.mass
    let temperatureFactor = min(1.0, temperature / Float(config.initialTemperature))

    for i in 0..<state.nodeCount {
        // Skip pinned nodes (they're handled separately)
        if state.pinned[i] {
            state.positions[i] = state.pinnedTargets[i]
            state.velocities[i] = .zero
            continue
        }

        // Update velocity with damping
        state.velocities[i] += (forces[i] / mass) * dt
        state.velocities[i] *= damping

        // Apply temperature scaling (simulated annealing)
        let scaledVelocity = state.velocities[i] * temperatureFactor

        // Update position
        state.positions[i] += scaledVelocity * dt
    }
}

/// Updates temperature using exponential cooling.
///
/// - Parameters:
///   - current: Current temperature
///   - config: Configuration parameters
/// - Returns: New temperature value
public func updateTemperature(current: Float, config: LayoutConfiguration) -> Float {
    return current * Float(config.coolingFactor)
}

/// Updates temperature using linear cooling.
///
/// - Parameters:
///   - initial: Initial temperature
///   - iteration: Current iteration number
///   - maxIterations: Maximum iterations
/// - Returns: New temperature value
public func linearCooling(initial: Float, iteration: Int, maxIterations: Int) -> Float {
    let progress = Float(iteration) / Float(maxIterations)
    return initial * (1.0 - progress)
}
