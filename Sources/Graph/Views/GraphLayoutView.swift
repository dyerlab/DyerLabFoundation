//
//  GraphLayoutView.swift
//  MatrixStuff
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
//  SwiftUI Canvas view for rendering force-directed graph layouts.
//  Refactored to use LayoutOrchestrator with SIMD3-based positions.
//

import SwiftUI

/// SwiftUI view for visualizing force-directed graph layouts.
///
/// A thin composition of three independently-previewable subviews:
/// ``GraphCanvasView`` (rendering + pan/zoom/drag gestures), ``GraphControlPanel``
/// (stats + play/pause/reset/reheat), and ``GraphInspectorPanel`` (rendering and
/// layout-physics sliders).
///
/// ## Features
///
/// - Real-time rendering at 60 FPS during animation
/// - Interactive node dragging with pinning
/// - Pan and zoom with Camera2D
/// - Node coloring and sizing
/// - Edge rendering with activation (smooth transitions)
/// - Control panel (play/pause, reset, reheat, stats)
/// - Automatic settle detection
///
/// ## Usage
///
/// ```swift
/// struct MyView: View {
///     let graph = Graph.smallGraph
///
///     var body: some View {
///         GraphLayoutView(
///             graph: graph,
///             configuration: LayoutConfiguration.smallGraph
///         )
///         .frame(width: 600, height: 600)
///     }
/// }
/// ```
public struct GraphLayoutView: View {

    /// The orchestrator managing the layout simulation.
    @State private var orchestrator: LayoutOrchestrator

    /// Camera for pan and zoom, shared between the canvas and the inspector's zoom controls.
    @State private var camera = Camera2D()

    /// Display/chrome options, shared between the control panel and inspector.
    @State private var options = GraphLayoutOptions()

    // MARK: - Initialization

    /// Creates a graph layout view with default configuration.
    ///
    /// - Parameter graph: The graph to visualize
    @MainActor public init(graph: Graph) {
        _orchestrator = State(initialValue: LayoutOrchestrator(graph: graph, config: LayoutConfiguration()))
    }

    /// Creates a graph layout view with custom configuration.
    ///
    /// - Parameters:
    ///   - graph: The graph to visualize
    ///   - configuration: Layout algorithm parameters
    @MainActor public init(graph: Graph, configuration: LayoutConfiguration) {
        _orchestrator = State(initialValue: LayoutOrchestrator(graph: graph, config: configuration))
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    GraphCanvasView(orchestrator: orchestrator, camera: $camera, options: options)

                    if options.showControls {
                        GraphControlPanel(orchestrator: orchestrator, camera: $camera, options: $options)
                            .padding()
                            #if os(macOS)
                            .background(Color(nsColor: .controlBackgroundColor))
                            #else
                            .background(Color(uiColor: .secondarySystemBackground))
                            #endif
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Right-side Inspector
                if options.showInspector {
                    Divider()

                    GraphInspectorPanel(orchestrator: orchestrator, camera: $camera, options: $options)
                        .frame(width: 280)
                        .frame(maxHeight: .infinity)
                        #if os(macOS)
                        .background(Color(nsColor: .controlBackgroundColor))
                        #else
                        .background(Color(uiColor: .secondarySystemBackground))
                        #endif
                }
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        options.showInspector.toggle()
                    } label: {
                        Label("Inspector", systemImage: options.showInspector ? "sidebar.right" : "sidebar.right")
                    }
                    .help("Toggle Inspector")
                }
            }
            .onAppear {
                orchestrator.start()
            }
        }
    }
}

// MARK: - Previews

#Preview("Small Graph") {
    GraphLayoutView(graph: Graph.smallGraph)
        .frame(width: 600, height: 600)
}

#Preview("Large Graph (lophoGraph)") {
    GraphLayoutView(graph: Graph.lophoGraph, configuration: LayoutConfiguration.largeGraph)
        .frame(width: 800, height: 800)
}

#Preview("Custom Configuration") {
    var config = LayoutConfiguration()
    config.k = 150.0
    config.coolingFactor = 0.92

    return GraphLayoutView(graph: Graph.smallGraph, configuration: config)
        .frame(width: 800, height: 800)
}
