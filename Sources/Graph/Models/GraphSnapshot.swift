//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GraphSnapshot.swift
//  Graph
//
//  `Graph`, `Node` and `Edge` are mutable reference types shared with the layout
//  engine, so they can't be `Sendable`. Anything that has to carry a graph across an
//  isolation boundary (an actor-backed store, a background task) carries this value
//  copy instead and rebuilds a live `Graph` on the far side with `makeGraph()`.
//
//  Created by Rodney Dyer on 2026.10.23.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import CoreLocation
import SwiftUI

/// An immutable, `Sendable` copy of a ``Graph``'s nodes and edges.
///
/// Node and edge identifiers are preserved, so metadata keyed by ``Node/id`` or
/// ``Edge/id`` still lines up after a round trip through ``makeGraph()``.
///
/// ```swift
/// let snapshot = GraphSnapshot(graph)          // on the caller's actor
/// let copy = snapshot.makeGraph()              // anywhere else
/// ```
public struct GraphSnapshot: Sendable, Equatable {

    /// The value form of one ``Node``.
    public struct NodeRecord: Sendable, Equatable {

        /// The node's identifier.
        public var id: UUID

        /// The node's label.
        public var name: String

        /// The node's visual size.
        public var size: Double

        /// The node's visual color.
        public var color: Color

        /// The node's latitude, or `nil` if it has no coordinate.
        public var latitude: Double?

        /// The node's longitude, or `nil` if it has no coordinate.
        public var longitude: Double?

        /// The node's categorical attributes.
        public var categoricalAttributes: [String: String]

        /// The node's continuous attributes.
        public var continuousAttributes: [String: Double]

        /// Creates a node record.
        ///
        /// - Parameters:
        ///   - id: The node's identifier (default: a new UUID).
        ///   - name: The node's label.
        ///   - size: The node's visual size.
        ///   - color: The node's visual color (default `.gray`).
        ///   - latitude: The node's latitude, or `nil`.
        ///   - longitude: The node's longitude, or `nil`.
        ///   - categoricalAttributes: Categorical attributes by name.
        ///   - continuousAttributes: Continuous attributes by name.
        public init(id: UUID = UUID(),
                    name: String,
                    size: Double,
                    color: Color = .gray,
                    latitude: Double? = nil,
                    longitude: Double? = nil,
                    categoricalAttributes: [String: String] = [:],
                    continuousAttributes: [String: Double] = [:]) {
            self.id = id
            self.name = name
            self.size = size
            self.color = color
            self.latitude = latitude
            self.longitude = longitude
            self.categoricalAttributes = categoricalAttributes
            self.continuousAttributes = continuousAttributes
        }

        /// Captures the current state of `node`.
        ///
        /// - Parameter node: The node to copy.
        public init(_ node: Node) {
            self.init(id: node.id,
                      name: node.name,
                      size: node.size,
                      color: node.color,
                      latitude: node.coordinate?.latitude,
                      longitude: node.coordinate?.longitude,
                      categoricalAttributes: node.categoricalAttributes,
                      continuousAttributes: node.continuousAttributes)
        }
    }

    /// The value form of one ``Edge``.
    public struct EdgeRecord: Sendable, Equatable {

        /// The edge's identifier.
        public var id: UUID

        /// The identifier of the source node.
        public var fromNode: UUID

        /// The identifier of the target node.
        public var toNode: UUID

        /// The edge weight.
        public var weight: Double

        /// Creates an edge record.
        ///
        /// - Parameters:
        ///   - id: The edge's identifier (default: a new UUID).
        ///   - fromNode: The identifier of the source node.
        ///   - toNode: The identifier of the target node.
        ///   - weight: The edge weight.
        public init(id: UUID = UUID(), fromNode: UUID, toNode: UUID, weight: Double) {
            self.id = id
            self.fromNode = fromNode
            self.toNode = toNode
            self.weight = weight
        }

        /// Captures the current state of `edge`.
        ///
        /// - Parameter edge: The edge to copy.
        public init(_ edge: Edge) {
            self.init(id: edge.id, fromNode: edge.fromNode, toNode: edge.toNode, weight: edge.weight)
        }
    }

    /// The graph's identifier.
    public var id: UUID

    /// The nodes, in the graph's node order.
    public var nodes: [NodeRecord]

    /// The edges, in the graph's edge order.
    public var edges: [EdgeRecord]

    /// Creates a snapshot from records.
    ///
    /// - Parameters:
    ///   - id: The graph's identifier (default: a new UUID).
    ///   - nodes: The nodes, in order.
    ///   - edges: The edges, in order. Each must reference nodes in `nodes`.
    public init(id: UUID = UUID(), nodes: [NodeRecord], edges: [EdgeRecord]) {
        self.id = id
        self.nodes = nodes
        self.edges = edges
    }

    /// Captures the current nodes and edges of `graph`.
    ///
    /// - Parameter graph: The graph to copy.
    public init(_ graph: Graph) {
        self.init(id: graph.id, nodes: graph.nodes.map(NodeRecord.init), edges: graph.edges.map(EdgeRecord.init))
    }

    /// Builds a new live ``Graph`` with the same identifiers, nodes and edges.
    ///
    /// - Returns: A graph that shares no references with any other graph.
    public func makeGraph() -> Graph {
        let graph = Graph()
        graph.id = id
        graph.nodes = nodes.map { record in
            let node = Node(name: record.name,
                            size: record.size,
                            color: record.color,
                            categoricalAttributes: record.categoricalAttributes,
                            continuousAttributes: record.continuousAttributes)
            node.id = record.id
            if let latitude = record.latitude, let longitude = record.longitude {
                node.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }
            return node
        }
        graph.edges = edges.map { Edge(id: $0.id, fromNode: $0.fromNode, toNode: $0.toNode, weight: $0.weight) }
        return graph
    }
}
