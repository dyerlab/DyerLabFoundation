//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GraphLayoutOptions.swift
//  Graph
//
//  Created by Rodney Dyer on 2026.08.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Display/chrome options for ``GraphLayoutView`` and its subviews.
///
/// Bundles the rendering knobs that are purely about presentation — as opposed
/// to layout physics, which already lives on `LayoutOrchestrator.config`
/// (`LayoutConfiguration`) and is bound to directly rather than mirrored here.
public struct GraphLayoutOptions: Equatable {

    /// Whether the bottom control panel (stats + play/pause/reset/reheat/fit) is visible.
    public var showControls: Bool

    /// Whether the right-side inspector (rendering/layout sliders) is visible.
    public var showInspector: Bool

    /// Whether node name labels are drawn beneath each node.
    public var showLabels: Bool

    /// Line width used to stroke edges.
    public var edgeLineWidth: Double

    /// Multiplier applied to each node's `size` when drawing.
    public var nodeSizeMultiplier: Double

    /// Creates display options.
    ///
    /// - Parameters:
    ///   - showControls: Whether the bottom control panel is visible.
    ///   - showInspector: Whether the right-side inspector is visible.
    ///   - showLabels: Whether node name labels are drawn.
    ///   - edgeLineWidth: Line width used to stroke edges.
    ///   - nodeSizeMultiplier: Multiplier applied to each node's `size`.
    public init(showControls: Bool = true, showInspector: Bool = true, showLabels: Bool = true,
                edgeLineWidth: Double = 1.0, nodeSizeMultiplier: Double = 1.0) {
        self.showControls = showControls
        self.showInspector = showInspector
        self.showLabels = showLabels
        self.edgeLineWidth = edgeLineWidth
        self.nodeSizeMultiplier = nodeSizeMultiplier
    }
}
