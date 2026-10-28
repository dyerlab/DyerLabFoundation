//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  LayoutState.swift
//  Graph
//
//  Simulation state for force-directed graph layout.
//  All arrays are parallel, indexed by graph.nodes array index.
//  SIMD3 allows seamless 2D (z=0) and 3D operation.
//
//  Created by Rodney Dyer on 2026.06.22.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import Foundation
import simd

/// Simulation state for force-directed layout.
///
/// All arrays are parallel, indexed by graph.nodes array index.
/// SIMD3 allows seamless 2D (z=0) and 3D operation.
public class LayoutState {
    // MARK: - Core State (per node)

    /// Node positions in world space (origin-centered).
    public var positions: [SIMD3<Float>]

    /// Node velocities for momentum-based integration.
    public var velocities: [SIMD3<Float>]

    /// Collision radius for each node (can change per window/locus).
    public var radii: [Float]

    // MARK: - Pinning (for direct manipulation)

    /// Whether each node is pinned by user interaction.
    public var pinned: [Bool]

    /// Target position for pinned nodes (set by drag gesture).
    public var pinnedTargets: [SIMD3<Float>]

    // MARK: - Motion

    /// Largest distance any single unpinned node moved in the most recent
    /// integration step, in world units.
    ///
    /// This is the visible, temperature-scaled motion, unlike
    /// ``kineticEnergy``, which uses raw velocities. Taking the maximum rather
    /// than a sum means one still-rearranging region keeps the layout running
    /// even when the rest of it has stopped.
    public var maxDisplacement: Float = 0

    // MARK: - Constants

    /// Mass per node (constant for stability).
    public let mass: Float = 1.0

    // MARK: - Metadata

    /// Number of nodes in this state.
    public let nodeCount: Int

    /// Current kinetic energy (sum of |v|² across all nodes).
    public var kineticEnergy: Float {
        velocities.reduce(0) { $0 + simd_length_squared($1) }
    }

    // MARK: - Initialization

    /// Creates a new layout state for the specified number of nodes.
    ///
    /// - Parameter nodeCount: Number of nodes in the graph
    public init(nodeCount: Int) {
        self.nodeCount = nodeCount
        self.positions = Array(repeating: .zero, count: nodeCount)
        self.velocities = Array(repeating: .zero, count: nodeCount)
        self.radii = Array(repeating: 10.0, count: nodeCount)
        self.pinned = Array(repeating: false, count: nodeCount)
        self.pinnedTargets = Array(repeating: .zero, count: nodeCount)
    }

    /// Randomizes node positions within a sphere or circle.
    ///
    /// - Parameters:
    ///   - radius: Maximum distance from origin
    ///   - mode2D: If true, constrains z=0 (2D layout)
    public func randomizePositions(radius: Float, mode2D: Bool = true) {
        for i in 0..<nodeCount {
            let x = Float.random(in: -radius...radius)
            let y = Float.random(in: -radius...radius)
            let z = mode2D ? 0.0 : Float.random(in: -radius...radius)
            positions[i] = SIMD3<Float>(x, y, z)
        }
    }

    /// Resets all velocities to zero.
    public func resetVelocities() {
        velocities = Array(repeating: .zero, count: nodeCount)
    }

    /// Scales all velocities by a factor (useful for damping during transitions).
    ///
    /// - Parameter factor: Scaling factor (e.g., 0.5 to halve all velocities)
    public func scaleVelocities(by factor: Float) {
        for i in 0..<nodeCount {
            velocities[i] *= factor
        }
    }

    /// Unpins all nodes.
    public func unpinAll() {
        for i in 0..<nodeCount {
            pinned[i] = false
        }
    }
}
