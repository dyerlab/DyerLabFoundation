//
//  Edge.swift
//  DLabPopGraph
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
//  Created by Rodney Dyer on 5/21/25.
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
    
    init(fromNode: Node, toNode: Node, weight: Double = 1.0 ) {
        self.id = UUID()
        self.fromNode = fromNode.id
        self.toNode = toNode.id
        self.weight = weight
    }
    
    public static func == (lhs: Edge, rhs: Edge) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
}






