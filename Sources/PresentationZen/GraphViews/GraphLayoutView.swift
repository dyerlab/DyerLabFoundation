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
//  GraphLayoutView.swift
//  MatrixStuff
//
//  SwiftUI Canvas view for rendering force-directed graph layouts.
//  Refactored to use LayoutOrchestrator with SIMD3-based positions.
//

import Graph
import SwiftUI
import Graph
import simd

/// SwiftUI view for visualizing force-directed graph layouts.
///
/// Renders nodes as colored circles and edges as lines using SwiftUI Canvas.
/// Uses the new LayoutOrchestrator with SIMD3-based positions and Camera2D transforms.
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

    // MARK: - Properties

    /// The orchestrator managing the layout simulation.
    @State private var orchestrator: LayoutOrchestrator

    /// Camera for pan and zoom.
    @State private var camera = Camera2D()

    /// Initial zoom for magnification gesture.
    @State private var initialZoom: Float = 1.0

    /// Whether to show the control panel.
    @State private var showControls: Bool = true

    /// Whether to show the right-side inspector.
    @State private var showInspector: Bool = true

    /// Whether to show node labels.
    @State private var showLabels: Bool = true

    /// Line width for edges.
    @State private var edgeLineWidth: Double = 1.0

    /// Node size multiplier.
    @State private var nodeSizeMultiplier: Double = 1.0

    /// Repulsion strength multiplier.
    @State private var repulsionStrength: Double = 1.0

    /// Attraction (spring) strength multiplier.
    @State private var attractionStrength: Double = 1.0

    /// Center gravity strength.
    @State private var centerGravity: Double = 0.5

    /// Currently dragged node index.
    @State private var draggedNodeIndex: Int?

    /// Last drag translation for background panning.
    @State private var lastTranslation: CGSize = .zero

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
                    // Canvas rendering with gesture overlay
                    GeometryReader { geometry in
                        ZStack {
                            Canvas { context, size in
                                // Draw edges first (behind nodes)
                                drawEdges(context: context, size: size)

                                // Draw nodes on top
                                drawNodes(context: context, size: size)
                            }
                            .background(Color(white: 0.95).opacity(0.3))
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        handleDrag(value: value, in: geometry.size)
                                    }
                                    .onEnded { _ in
                                        if let nodeIndex = draggedNodeIndex {
                                            orchestrator.unpinNode(at: nodeIndex)
                                        }
                                        draggedNodeIndex = nil
                                        lastTranslation = .zero
                                    }
                            )
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        camera.zoom = max(0.1, min(5.0, Float(value) * initialZoom))
                                    }
                                    .onEnded { _ in
                                        initialZoom = camera.zoom
                                    }
                            )
                        }
                    }

                    // Control panel
                    if showControls {
                        controlPanel
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
                if showInspector {
                    Divider()

                    inspectorPanel
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
                        showInspector.toggle()
                    } label: {
                        Label("Inspector", systemImage: showInspector ? "sidebar.right" : "sidebar.right")
                    }
                    .help("Toggle Inspector")
                }
            }
            .onAppear {
                orchestrator.start()
            }
        }
    }

    // MARK: - Drag Handling

    private func handleDrag(value: DragGesture.Value, in size: CGSize) {
        let viewPoint = value.location

        // On first frame, hit test
        if draggedNodeIndex == nil && lastTranslation == .zero {
            // Try to hit test a node
            if let nodeIndex = hitTest(viewPoint: viewPoint, state: orchestrator.state, camera: camera, canvasSize: size) {
                draggedNodeIndex = nodeIndex
                let worldPoint = viewToWorld(viewPoint: viewPoint, canvasSize: size, camera: camera)
                orchestrator.pinNode(at: nodeIndex, position: worldPoint)
            }
        }

        // Update pinned target or pan camera
        if let nodeIndex = draggedNodeIndex {
            let worldPoint = viewToWorld(viewPoint: viewPoint, canvasSize: size, camera: camera)
            orchestrator.state.pinnedTargets[nodeIndex] = worldPoint
        } else {
            // Background pan
            camera.pan.x += Float(value.translation.width - lastTranslation.width)
            camera.pan.y += Float(value.translation.height - lastTranslation.height)
            lastTranslation = value.translation
        }
    }

    // MARK: - Drawing Methods

    /// Draws all edges as lines.
    private func drawEdges(context: GraphicsContext, size: CGSize) {
        for (edgeIndex, edge) in orchestrator.graph.edges.enumerated() {
            guard let fromNode = orchestrator.graph.node(id: edge.fromNode),
                  let toNode = orchestrator.graph.node(id: edge.toNode),
                  let fromIndex = orchestrator.graph.nodes.firstIndex(of: fromNode),
                  let toIndex = orchestrator.graph.nodes.firstIndex(of: toNode) else { continue }

            let pos1 = orchestrator.state.positions[fromIndex]
            let pos2 = orchestrator.state.positions[toIndex]

            let viewPos1 = worldToView(worldPoint: pos1, canvasSize: size, camera: camera)
            let viewPos2 = worldToView(worldPoint: pos2, canvasSize: size, camera: camera)

            var path = SwiftUI.Path()
            path.move(to: viewPos1)
            path.addLine(to: viewPos2)

            // Edge opacity based on activation and weight
            let alpha = orchestrator.edgeStates.states[edgeIndex].alpha
            let weightAlpha = Float(min(0.3 + (edge.weight / 20.0), 0.8))
            let finalAlpha = alpha * weightAlpha

            context.stroke(
                path,
                with: .color(.gray.opacity(Double(finalAlpha))),
                lineWidth: edgeLineWidth
            )
        }
    }

    /// Draws all nodes as circles with optional labels.
    private func drawNodes(context: GraphicsContext, size: CGSize) {
        for (nodeIndex, node) in orchestrator.graph.nodes.enumerated() {
            let worldPos = orchestrator.state.positions[nodeIndex]
            let viewPos = worldToView(worldPoint: worldPos, canvasSize: size, camera: camera)

            let radius = CGFloat(node.size * nodeSizeMultiplier) * CGFloat(camera.zoom)
            let nodeRect = CGRect(
                x: viewPos.x - radius/2,
                y: viewPos.y - radius/2,
                width: radius,
                height: radius
            )

            // Fill circle with node color
            context.fill(
                Circle().path(in: nodeRect),
                with: .color(node.color)
            )

            // Stroke circle outline
            let isBeingDragged = draggedNodeIndex == nodeIndex
            context.stroke(
                Circle().path(in: nodeRect),
                with: .color(isBeingDragged ? .blue : .black),
                lineWidth: isBeingDragged ? 2 : 1
            )

            // Draw node label if enabled
            if showLabels {
                let labelText = Text(node.name)
                    .font(.caption)
                    .foregroundColor(.primary)

                context.draw(
                    labelText,
                    at: CGPoint(x: viewPos.x, y: viewPos.y + radius/2 + 10)
                )
            }
        }
    }

    // MARK: - Control Panel

    /// Control panel UI.
    private var controlPanel: some View {
        VStack(spacing: 12) {
            // Stats row
            HStack(spacing: 20) {
                Label("Iteration: \(orchestrator.iteration)", systemImage: "number")
                    .font(.caption)

                Label("Temp: \(String(format: "%.1f", orchestrator.temperature))", systemImage: "thermometer")
                    .font(.caption)

                Label("Energy: \(String(format: "%.2f", orchestrator.kineticEnergy))", systemImage: "bolt.fill")
                    .font(.caption)

                if orchestrator.isSettled {
                    Label("Settled", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                Spacer()
            }

            Divider()

            // Control buttons
            HStack(spacing: 16) {
                Button(action: {
                    if orchestrator.isRunning {
                        orchestrator.stop()
                    } else {
                        orchestrator.start()
                    }
                }) {
                    Label(
                        orchestrator.isRunning ? "Pause" : "Start",
                        systemImage: orchestrator.isRunning ? "pause.fill" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)

                Button(action: {
                    orchestrator.reset()
                    orchestrator.start()
                }) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)

                Button(action: {
                    orchestrator.reheat()
                }) {
                    Label("Reheat", systemImage: "flame")
                }
                .buttonStyle(.bordered)

                Button(action: {
                    camera = fitToView(state: orchestrator.state, canvasSize: CGSize(width: 600, height: 600))
                }) {
                    Label("Fit", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.bordered)

                // Label toggle
                Toggle(isOn: $showLabels) {
                    Label("Labels", systemImage: "textformat")
                        .font(.caption)
                }
                .toggleStyle(.button)

                Spacer()
            }
        }
    }

    /// Right-side inspector UI for layout and rendering controls.
    private var inspectorPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Inspector")
                    .font(.headline)
                Spacer()
                Button {
                    showInspector = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Close Inspector")
            }

            Divider()

            Group {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Edge Width")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $edgeLineWidth, in: 0.5...3.0)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Node Size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $nodeSizeMultiplier, in: 0.50...2.0)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Repulsion: \(String(format: "%.1f", repulsionStrength))×")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $repulsionStrength, in: 0.1...3.0)
                        .onChange(of: repulsionStrength) { _, newValue in
                            orchestrator.config.repulsionStrength = newValue
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Attraction: \(String(format: "%.1f", attractionStrength))×")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $attractionStrength, in: 0.1...5.0)
                        .onChange(of: attractionStrength) { _, newValue in
                            orchestrator.config.attractionStrength = newValue
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Gravity: \(String(format: "%.1f", centerGravity))×")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $centerGravity, in: 0.0...3.0)
                        .onChange(of: centerGravity) { _, newValue in
                            orchestrator.config.centerGravity = newValue
                        }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Zoom: \(String(format: "%.1f", camera.zoom))×")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Button("-") {
                        camera.zoom = max(0.1, camera.zoom - 0.1)
                        initialZoom = camera.zoom
                    }
                    .buttonStyle(.bordered)

                    Button("Reset") {
                        camera.zoom = 1.0
                        camera.pan = .zero
                        initialZoom = camera.zoom
                    }
                    .buttonStyle(.bordered)

                    Button("+") {
                        camera.zoom = min(5.0, camera.zoom + 0.1)
                        initialZoom = camera.zoom
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Previews

#if !SPM_BUILD
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
#endif
