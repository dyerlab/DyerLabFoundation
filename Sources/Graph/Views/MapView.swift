//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MapView.swift
//  Graph
//
//  Created by Rodney Dyer on 2025.05.21.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI
import MapKit

/// A satellite map of a graph whose nodes have coordinates.
///
/// Edges are drawn as polylines between their endpoints. Tapping a node opens a
/// `NodeInspectorForm` for it (not on visionOS). Nodes without a coordinate,
/// and edges touching them, are skipped.
public struct MapView: View {
    /// The graph to draw; edits made in the node inspector are written back to it.
    @Binding public var graph: Graph
    /// Line width used to stroke edges.
    @Binding public var lineWidth: CGFloat
    /// Divisor applied to each node's `size` when drawing its marker.
    @Binding public var nodeScaling: CGFloat

    @State private var selectedNodeID: UUID? = nil
    @State private var isPresentingInspector: Bool = false

    /// Creates a map of `graph`.
    ///
    /// - Parameters:
    ///   - graph: The graph to draw.
    ///   - lineWidth: Line width used to stroke edges.
    ///   - nodeScaling: Divisor applied to each node's `size` when drawing its marker.
    public init(graph: Binding<Graph>, lineWidth: Binding<CGFloat>, nodeScaling: Binding<CGFloat>) {
        self._graph = graph
        self._lineWidth = lineWidth
        self._nodeScaling = nodeScaling
    }

    public var body: some View {

        Map {

            // Lay out the edges
            ForEach(graph.edges, id: \.self) { edge in
                if let pt1 = graph.node(id: edge.fromNode)?.coordinate,
                   let pt2 = graph.node(id: edge.toNode)?.coordinate {
                    MapPolyline(coordinates: [pt1, pt2])
                        .stroke(.gray, lineWidth: lineWidth)
                }
            }

            // Lay out the nodes
            ForEach(graph.nodes, id: \.self) { node in
                if let coord = node.coordinate {
                    Annotation(node.name,
                               coordinate: coord) {
                        Button(action: {
                            selectedNodeID = node.id
                            isPresentingInspector = true
                        }) {
                            Circle()
                                .fill(node.color)
                                .scaleEffect(node.size / nodeScaling)
                        }
                        .buttonStyle(.plain) // Avoids any button styling
                    }
                }
            }
        }
        .mapStyle(MapStyle.hybrid)
        .mapControls {
            MapScaleView()
            MapCompass()
            MapPitchToggle()

            #if os(macOS)
            MapZoomStepper()
            MapPitchSlider()
            #endif 
        }
        // .inspector(isPresented:content:) is unavailable on visionOS. This is a
        // compile-fix, not a visionOS UX story for MapView — that's a separate concern.
        #if !os(visionOS)
        .inspector(isPresented: $isPresentingInspector) {
            if let index = graph.nodes.firstIndex(where: { $0.id == selectedNodeID }) {
                NodeInspectorForm(node: $graph.nodes[index])
            }
        }
        #endif

    }
}

enum MapStyleOption: String, CaseIterable, Hashable {
    case standard, imagery, hybrid

    var mapStyle: MapStyle {
        switch self {
        case .standard:
            return .standard(elevation: .realistic)
        case .imagery:
            return .imagery(elevation: .realistic)
        case .hybrid:
            return .hybrid(elevation: .realistic)
        }
    }
}

// MARK: - Previews

#Preview {
    MapView(
        graph: .constant(Graph.lophoGraph),
        lineWidth: .constant(1.0),
        nodeScaling: .constant(10.0)
    )
}
