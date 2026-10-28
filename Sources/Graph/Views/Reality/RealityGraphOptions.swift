//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RealityGraphOptions.swift
//  Graph
//
//  Created by Rodney Dyer on 2026.08.09.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Display/chrome options for ``RealityGraphView`` and its supporting types.
///
/// Bundles the rendering knobs that are purely about presentation — as opposed
/// to layout physics, which already lives on `LayoutOrchestrator.config`
/// (`LayoutConfiguration`) and is bound to directly rather than mirrored here.
/// Mirrors ``GraphLayoutOptions``'s shape for the Canvas-based 2D view.
public struct RealityGraphOptions: Equatable {

    /// Whether node name labels are drawn near each node.
    public var showLabels: Bool

    /// Multiplier applied to each node's `size` when generating its sphere.
    public var nodeSizeMultiplier: Double

    /// Radius of the cylinder/box geometry used to draw an edge.
    public var edgeThickness: Float

    /// Whether a default environment light is added to the scene.
    public var environmentLighting: Bool

    /// Whether nodes visibly move during the headless precompute phase (before
    /// physics takes over), vs. staying hidden until the layout has settled.
    public var showPrecomputeAnimation: Bool

    /// Creates display options.
    ///
    /// - Parameters:
    ///   - showLabels: Whether node name labels are drawn.
    ///   - nodeSizeMultiplier: Multiplier applied to each node's `size`.
    ///   - edgeThickness: Radius of the geometry used to draw an edge.
    ///   - environmentLighting: Whether a default environment light is added.
    ///   - showPrecomputeAnimation: Whether nodes move visibly before physics takes over.
    public init(showLabels: Bool = true, nodeSizeMultiplier: Double = 1.0, edgeThickness: Float = 0.01,
                environmentLighting: Bool = true, showPrecomputeAnimation: Bool = true) {
        self.showLabels = showLabels
        self.nodeSizeMultiplier = nodeSizeMultiplier
        self.edgeThickness = edgeThickness
        self.environmentLighting = environmentLighting
        self.showPrecomputeAnimation = showPrecomputeAnimation
    }
}
