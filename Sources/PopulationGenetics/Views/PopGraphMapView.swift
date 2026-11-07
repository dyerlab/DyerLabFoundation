//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopGraphMapView.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.10.24.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import MapKit
import SwiftUI
import PresentationZen

/// A population graph drawn on a map: each node at its population's centroid,
/// sized by within-population variance, with edges as straight lines.
public struct PopGraphMapView: View {

    /// A node with the coordinate it is drawn at.
    private struct PlacedNode: Identifiable {
        /// The node's identity in the graph.
        public let id: UUID
        /// The population's name.
        public let name: String
        /// The node's within-population variance.
        public let size: Double
        /// Where the node is drawn.
        public let coordinate: CLLocationCoordinate2D
    }

    /// The graph to draw.
    public let graph: PopulationGraphDataset
    /// Each population's current centroid, by name.
    ///
    /// Nodes are drawn here, so coordinate edits move them without re-estimating the graph.
    public let centroids: [String: CLLocationCoordinate2D]

    @State private var style: MapBaseStyle = .standard

    /// Creates a map of a graph.
    ///
    /// - Parameters:
    ///   - graph: The graph to draw.
    ///   - centroids: Each population's current centroid, by name.
    public init(graph: PopulationGraphDataset, centroids: [String: CLLocationCoordinate2D]) {
        self.graph = graph
        self.centroids = centroids
    }

    public var body: some View {
        let nodes = placedNodes
        let positions = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.coordinate) })
        Map {
            ForEach(graph.graph.edges, id: \.id) { edge in
                if let from = positions[edge.fromNode], let to = positions[edge.toNode] {
                    MapPolyline(coordinates: [from, to])
                        .stroke(style == .satellite ? Color.white.opacity(0.85) : Color.accentColor.opacity(0.7),
                                lineWidth: 2)
                }
            }
            ForEach(nodes) { node in
                Annotation(node.name, coordinate: node.coordinate, anchor: .center) {
                    NodeMarker(size: node.size)
                }
            }
        }
        .mapStyle(style.mapStyle)
        .mapControls {
            #if os(macOS)
            MapZoomStepper()
            #endif
            MapScaleView()
        }
        .overlay(alignment: .topLeading) {
            MapStylePicker(style: $style)
        }
    }

    /// The nodes that have a position: the current centroid, else the one
    /// saved with the graph.
    private var placedNodes: [PlacedNode] {
        graph.graph.nodes.compactMap { record in
            let saved = record.latitude.flatMap { latitude in
                record.longitude.map { CLLocationCoordinate2D(latitude: latitude, longitude: $0) }
            }
            guard let coordinate = centroids[record.name] ?? saved else { return nil }
            return PlacedNode(id: record.id, name: record.name, size: record.size, coordinate: coordinate)
        }
    }
}

// MARK: - Previews

#Preview {
    if let dataset = try? ExampleDataset.arapatPopulations.load(),
       let graph = PopulationGraphBuilder.estimate(from: dataset) {
        PopGraphMapView(graph: graph,
                        centroids: Dictionary(uniqueKeysWithValues: PopulationClusters(dataset: dataset).clusters
                            .map { ($0.name, $0.centroid) }))
            .frame(width: 700, height: 600)
    }
}
