//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Edge.swift
//  Graph
//
//  Created by Rodney Dyer on 2025.05.21.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import Foundation

/// A directed edge connecting two nodes in a graph.
///
/// Edges are directed from a source node to a target node and have an optional weight.
/// Each edge has a unique identifier.
///
/// ## Example
/// ```swift
/// let nodeA = Node(name: "A", size: 1.0)
/// let nodeB = Node(name: "B", size: 1.0)
/// let edge = Edge(fromNode: nodeA, toNode: nodeB, weight: 2.5)
/// ```
public class Edge: Identifiable, Equatable, Hashable {

    /// Unique identifier for the edge.
    public var id: UUID

    /// UUID of the source node.
    public var fromNode: UUID

    /// UUID of the target node.
    public var toNode: UUID

    /// Edge weight (default: 1.0).
    public var weight: Double

    /// Creates an edge between two nodes.
    ///
    /// - Parameters:
    ///   - fromNode: The source node.
    ///   - toNode: The target node.
    ///   - weight: The edge weight (default `1.0`).
    public convenience init(fromNode: Node, toNode: Node, weight: Double = 1.0) {
        self.init(fromNode: fromNode.id, toNode: toNode.id, weight: weight)
    }

    /// Creates an edge between two nodes identified by their ``Node/id``.
    ///
    /// - Parameters:
    ///   - id: The edge's identifier (default: a new UUID).
    ///   - fromNode: The identifier of the source node.
    ///   - toNode: The identifier of the target node.
    ///   - weight: The edge weight (default `1.0`).
    public init(id: UUID = UUID(), fromNode: UUID, toNode: UUID, weight: Double = 1.0) {
        self.id = id
        self.fromNode = fromNode
        self.toNode = toNode
        self.weight = weight
    }

    public static func == (lhs: Edge, rhs: Edge) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

}
