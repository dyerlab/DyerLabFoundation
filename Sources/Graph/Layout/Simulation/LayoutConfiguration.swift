//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  LayoutConfiguration.swift
//  Graph
//
//  Force-directed layout configuration parameters.
//
//  Created by Rodney Dyer on 2026.06.22.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import Foundation

#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Configuration parameters for graph layout algorithms.
///
/// Selects the algorithm (``algorithm``) and controls the behavior of the
/// Fruchterman-Reingold layout, including force strengths, cooling schedule,
/// physics parameters, and boundary constraints.
///
/// ## Example
/// ```swift
/// var config = LayoutConfiguration()
/// config.k = 150.0  // Increase ideal spring length
/// config.coolingFactor = 0.98  // Slower cooling for smoother convergence
/// config.bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
///
/// let orchestrator = LayoutOrchestrator(graph: graph, config: config)
/// ```
public struct LayoutConfiguration {

    // MARK: - Algorithm Selection

    /// Which layout algorithm drives the simulation.
    ///
    /// Changing it on a running orchestrator takes effect on the next
    /// ``LayoutOrchestrator/reset()``; use ``LayoutOrchestrator/setAlgorithm(_:)``
    /// to switch and restart in one call.
    ///
    /// Default: `.fruchtermanReingold`
    public var algorithm: LayoutAlgorithm = .fruchtermanReingold

    /// How edge weights become distances under `.kamadaKawai`.
    ///
    /// The default matches gstudio's `layout = "kk"`. The force-directed
    /// parameters below (temperature, damping, repulsion, …) do not apply to
    /// Kamada–Kawai; `k` only sets its on-screen scale (the mean edge's ideal
    /// length is drawn `k` units long).
    ///
    /// Default: `.flooredEdgeWeights(medianFraction: 0.25)`
    public var kamadaKawaiWeighting: KamadaKawaiWeighting = .flooredEdgeWeights()

    /// Kamada–Kawai move budget per node: a run takes this many × n
    /// single-node moves (n per animation frame, so this is also the frame
    /// count). igraph's and gstudio's default is 50. Larger graphs, or ones with
    /// several components, may need more to come to rest — the orchestrator's
    /// ``LayoutOrchestrator/settleOutcome`` suggests a value when they do.
    ///
    /// Default: 50
    public var kamadaKawaiMovesPerNode: Int = 50

    // MARK: - Algorithm Parameters

    /// Ideal spring length multiplier (k).
    ///
    /// Controls the base length for edges. Edge weights are multiplied by this value
    /// to determine ideal spring lengths. Larger values spread nodes further apart.
    ///
    /// Default: 200.0
    public var k: Double = 200.0

    /// Canvas area for automatic k calculation (currently unused).
    ///
    /// Can be used to automatically adjust k based on canvas size:
    /// `k = sqrt(area / nodeCount)`
    ///
    /// Default: 250,000.0 (500×500)
    public var area: Double = 250_000.0

    // MARK: - Physics Parameters

    /// Initial temperature for the cooling schedule.
    ///
    /// Higher temperatures allow larger position changes early in the simulation.
    /// Temperature decreases over time according to the cooling factor.
    ///
    /// Default: 500.0
    public var initialTemperature: Double = 500.0

    /// Cooling factor applied each iteration (0.0 to 1.0).
    ///
    /// Temperature is multiplied by this value each step: `temp *= coolingFactor`
    /// - Values closer to 1.0: slower cooling, smoother convergence
    /// - Values closer to 0.0: faster cooling, quicker convergence
    ///
    /// Default: 0.99
    public var coolingFactor: Double = 0.99

    /// Velocity damping factor (0.0 to 1.0).
    ///
    /// Reduces velocity each iteration to simulate friction and stabilize the layout.
    /// - 1.0: No damping (perpetual motion)
    /// - 0.0: Immediate stop (no momentum)
    ///
    /// Default: 0.9
    public var damping: Double = 0.9

    // MARK: - Simulation Parameters

    /// Maximum number of force-directed steps before auto-stopping.
    ///
    /// A backstop: layouts normally settle earlier, when motion falls below
    /// ``settleThreshold``. Counted from the last start, reset or resume, and
    /// only enforced when ``autoSettle`` is on. Kamada–Kawai uses its own
    /// 50·n-move budget instead.
    ///
    /// Default: 1000
    public var maxIterations: Int = 1000

    /// Convergence threshold for average force magnitude.
    ///
    /// Simulation converges when average force per node falls below this value.
    /// Lower values require more precision before stopping.
    ///
    /// Default: 0.1
    public var convergenceThreshold: Double = 0.1

    /// Time step for physics integration (seconds).
    ///
    /// Smaller values are more accurate but require more iterations.
    /// Default corresponds to ~60 FPS.
    ///
    /// Default: 0.016 (1/60 second)
    public var deltaTime: Double = 0.016

    // MARK: - Boundary Constraints

    /// Bounding rectangle for node positions.
    ///
    /// Nodes will be constrained to this region using boundary forces or hard clamps.
    public var bounds: CGRect

    /// Whether to use soft boundary forces.
    ///
    /// - `true`: Repulsive forces push nodes away from boundaries
    /// - `false`: Nodes can move freely outside bounds
    ///
    /// Default: true
    public var useBoundaryForces: Bool = true

    /// Strength of boundary repulsion forces.
    ///
    /// Higher values create stronger "walls" at the boundary edges.
    ///
    /// Default: 1000.0
    public var boundaryForceStrength: Double = 1000.0

    // MARK: - Edge Weight Interpretation

    /// Whether to use edge weights as ideal spring lengths.
    ///
    /// - `true`: Ideal length = `edge.weight * k`
    /// - `false`: All edges have the same ideal length `k`
    ///
    /// Default: true
    public var useEdgeWeightsAsLengths: Bool = true

    /// Multiplier for edge weights when calculating spring lengths.
    ///
    /// Final ideal length = `edge.weight * edgeWeightScale * k`
    ///
    /// Default: 1.0
    public var edgeWeightScale: Double = 1.0

    /// Multiplier for repulsive force strength.
    ///
    /// Controls how strongly nodes repel each other. Higher values create more spacing.
    /// - Values > 1.0: Stronger repulsion, nodes spread further apart
    /// - Values < 1.0: Weaker repulsion, nodes can get closer
    ///
    /// Default: 1.0
    public var repulsionStrength: Double = 1.0

    /// Multiplier for attractive (spring) force strength.
    ///
    /// Controls how strongly edges pull connected nodes together.
    /// - Values > 1.0: Stronger attraction, tighter edge lengths
    /// - Values < 1.0: Weaker attraction, looser edge lengths
    ///
    /// Default: 1.0
    public var attractionStrength: Double = 1.0

    /// Center gravity strength.
    ///
    /// Pulls all nodes toward the center of the layout bounds to prevent drift to edges.
    /// This is crucial for preventing the common issue where repulsion pushes nodes off-screen.
    /// - 0.0: No center gravity (nodes can drift freely)
    /// - 0.5-2.0: Weak to moderate pull (typical range)
    /// - 3.0+: Strong pull toward center
    ///
    /// Default: 0.5
    public var centerGravity: Double = 0.5

    /// Whether to use collision detection to prevent node overlap.
    ///
    /// When enabled, nodes are treated as circles and strong repulsive forces prevent overlap.
    ///
    /// Default: true
    public var useCollisionDetection: Bool = true

    /// Collision force strength.
    ///
    /// Multiplier for forces that prevent nodes from overlapping.
    /// Higher values create stronger separation when nodes collide.
    ///
    /// Default: 10.0
    public var collisionForceStrength: Double = 10.0

    // MARK: - 2D/3D Mode

    /// Enable z-flattening force for 2D mode.
    ///
    /// When true, applies force: F_z = -k_flatten × position.z
    /// This constrains the layout to the xy-plane (z=0).
    ///
    /// Default: true
    public var mode2D: Bool = true

    /// Z-flattening force strength (for 2D mode).
    ///
    /// Controls how strongly nodes are pulled toward z=0.
    /// Only active when mode2D is true.
    ///
    /// Default: 100.0
    public var zFlatteningStrength: Float = 100.0

    // MARK: - Settle Detection

    /// Enable automatic settle detection and pause.
    ///
    /// When true, the simulation will automatically pause when the layout
    /// has stopped visibly moving (see ``settleThreshold``) or has run
    /// ``maxIterations`` steps.
    ///
    /// Default: true
    public var autoSettle: Bool = true

    /// Motion threshold for settle detection, in world units per frame.
    ///
    /// The layout settles once no single node moves farther than this in a frame
    /// (for ``settleFrameCount`` frames in a row). It is measured on the most
    /// mobile node, not averaged, so a region still rearranging keeps the layout
    /// running. The goal is a readable topology, not sub-pixel precision.
    ///
    /// Default: 0.05
    public var settleThreshold: Float = 0.05

    /// Number of consecutive frames below threshold to declare settled.
    ///
    /// Prevents false positives from momentary pauses in motion.
    ///
    /// Default: 10
    public var settleFrameCount: Int = 10

    // MARK: - Initializers

    /// Creates a layout configuration with default values.
    ///
    /// - Parameter bounds: The bounding rectangle for layout (default: 2000×2000 for room to spread)
    ///
    /// Note: The bounds should be larger than the view area to give nodes room to spread out.
    /// Use zoom to fit the layout into the visible viewport.
    public init(bounds: CGRect = CGRect(x: 0, y: 0, width: 2000, height: 2000)) {
        self.bounds = bounds
    }

    /// Default configuration preset.
    ///
    /// Returns a configuration with standard parameter values suitable for most graphs.
    public static var `default`: LayoutConfiguration {
        return LayoutConfiguration()
    }

    /// Configuration preset optimized for small graphs (< 20 nodes).
    public static var smallGraph: LayoutConfiguration {
        var config = LayoutConfiguration()
        config.k = 250.0  // Larger spacing
        config.initialTemperature = 600.0  // Higher starting temperature
        config.damping = 0.85  // More damping for stability
        config.coolingFactor = 0.985  // Moderate cooling
        config.centerGravity = 0.8  // Stronger center pull
        return config
    }

    /// Configuration preset optimized for large graphs (> 100 nodes).
    public static var largeGraph: LayoutConfiguration {
        var config = LayoutConfiguration()
        config.k = 150.0  // Moderate spacing (was too tight)
        config.initialTemperature = 400.0  // Lower for faster convergence
        config.maxIterations = 2000  // Slower cooling settles later (lopho: ~830 steps)
        config.coolingFactor = 0.995  // Slower cooling for large graphs
        config.centerGravity = 1.0  // Strong center pull to prevent edge drift
        return config
    }

    /// Configuration preset for graphs whose edge weights are real distances
    /// (e.g. a population graph's genetic-distance-weighted edges), rather than
    /// generic unit weights.
    ///
    /// `useEdgeWeightsAsLengths` (the default, `true`) means `idealLength = edge.weight
    /// * k` — with `.largeGraph`'s `k = 150`, real distance weights spanning a wide
    /// range (e.g. `lophoGraph`'s ~1.4 to ~14.2) demand mutually-incompatible ideal
    /// lengths (up to ~2100 units) that a modest-sized graph can't satisfy, so the
    /// layout never settles into a compact, low-tension arrangement — confirmed via a
    /// real settle-and-measure run against `lophoGraph`: `.largeGraph` as-is leaves a
    /// mean edge-length error of ~280 units against a sprawling ~1800×1500 bounding
    /// box. A much smaller `k` scaled to the data, plus a slower cooling schedule
    /// giving the system more time to find a compromise before freezing, brings that
    /// down to a mean error of ~45–65 units in a compact ~350–500-unit box — still a
    /// non-zero residual (real distance data of this kind is rarely perfectly
    /// 2D-embeddable, the same as any multidimensional-scaling stress term), but a
    /// visually organized, non-sprawling result instead of a frozen high-tension one.
    ///
    /// `k` is deliberately not auto-derived from the graph's own edge weights here —
    /// pass a `k` sized to your own data's typical edge weight if it differs much
    /// from lopho's (roughly, aim for `meanEdgeWeight * k` in the low hundreds).
    ///
    /// - Parameter k: The base spring length (default `30`).
    /// - Returns: A configuration tuned for distance-weighted edges.
    public static func distanceWeightedGraph(k: Double = 30.0) -> LayoutConfiguration {
        var config = LayoutConfiguration()
        config.k = k
        config.initialTemperature = 500.0
        config.coolingFactor = 0.998  // Slower cooling — gives the system time to resolve disagreements before freezing
        config.maxIterations = 2000  // Slower cooling settles later (lopho: ~860 steps)
        config.centerGravity = 1.0
        return config
    }
}
