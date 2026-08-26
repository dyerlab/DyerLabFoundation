//  
//  Path.swift
//  DyerLabFoundation
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

/// A path through a graph from a source to a destination.
///
/// Represents the shortest path between two nodes, including the sequence of nodes
/// traversed and the total distance.
///
/// Typically created by graph algorithms like Dijkstra's shortest path.
///
/// ## Example
/// ```swift
/// if let path = graph.shortestPath(from: "A", to: "C") {
///     print("Distance:", path.distance)
///     print("Route:", path.sequence.map { $0.name })
/// }
/// ```
public struct Path: Identifiable, Hashable, CustomStringConvertible {
    /// Unique identifier for the path.
    public var id: UUID

    /// The starting node.
    public var source: Node

    /// The ending node.
    public var destination: Node

    /// Ordered sequence of nodes from source to destination (inclusive).
    public var sequence: [Node]

    /// Total distance along the path (sum of edge weights).
    public var distance: Double
    
    public init(source: Node, destination: Node ) {
        self.id = UUID()
        self.source = source
        self.destination = destination
        self.sequence = []
        self.distance = 0.0
    }
    
    public static func == (lhs: Path, rhs: Path) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public var description: String {
        var ret = "\(source.name) -> \(destination.name); dist=\(distance); path = "
        for node in sequence {
            if node != sequence.first! {
                ret += " -> \(node.name)"
            } else {
                ret += "\(node.name)"
            }
        }
        return ret
    }
    
}
