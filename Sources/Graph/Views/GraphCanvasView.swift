//
//  GraphCanvasView.swift
//  DyerlabFoundation
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
//  The Canvas-rendering half of GraphLayoutView, split out on its own so
//  Xcode's canvas can preview and inspect it independently of the
//  surrounding control/inspector chrome.
//

import SwiftUI

/// Renders a graph's current layout as colored circles and lines, with pan/zoom
/// and node-drag gestures.
///
/// Owns only the state needed to interpret its own gestures (drag/zoom in
/// progress); the shared ``Camera2D`` is passed in as a binding so sibling
/// views (e.g. an inspector's zoom controls) can read and drive it too.
public struct GraphCanvasView: View {

    let orchestrator: LayoutOrchestrator
    @Binding var camera: Camera2D
    var options: GraphLayoutOptions

    /// The camera zoom at the start of the in-progress pinch gesture, captured
    /// lazily on its first `onChanged` so each new gesture is always relative
    /// to whatever `camera.zoom` currently is — including zoom changes made
    /// elsewhere (inspector +/- buttons, "Fit") while no gesture is active.
    @State private var pinchBaselineZoom: Float?
    @State private var draggedNodeIndex: Int?
    @State private var lastTranslation: CGSize = .zero

    public init(orchestrator: LayoutOrchestrator, camera: Binding<Camera2D>, options: GraphLayoutOptions) {
        self.orchestrator = orchestrator
        self._camera = camera
        self.options = options
    }

    public var body: some View {
        GeometryReader { geometry in
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
                        let baseline = pinchBaselineZoom ?? camera.zoom
                        pinchBaselineZoom = baseline
                        camera.zoom = max(0.1, min(5.0, Float(value) * baseline))
                    }
                    .onEnded { _ in
                        pinchBaselineZoom = nil
                    }
            )
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
                lineWidth: options.edgeLineWidth
            )
        }
    }

    /// Draws all nodes as circles with optional labels.
    private func drawNodes(context: GraphicsContext, size: CGSize) {
        for (nodeIndex, node) in orchestrator.graph.nodes.enumerated() {
            let worldPos = orchestrator.state.positions[nodeIndex]
            let viewPos = worldToView(worldPoint: worldPos, canvasSize: size, camera: camera)

            let radius = CGFloat(node.size * options.nodeSizeMultiplier) * CGFloat(camera.zoom)
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
            if options.showLabels {
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
}

// MARK: - Previews

#Preview("Small Graph") {
    @Previewable @State var camera = Camera2D()
    let orchestrator = LayoutOrchestrator(graph: Graph.smallGraph)

    return GraphCanvasView(orchestrator: orchestrator, camera: $camera, options: GraphLayoutOptions())
        .frame(width: 600, height: 600)
        .onAppear { orchestrator.start() }
}
