//
//  GraphSubtraction.swift
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
//  A port of gstudio's `-.popgraph` operator: the edges of one population graph
//  with the edges of another removed (offspring minus parent).
//  See `~/Coding/gstudio/R/ops_popgraph.R`.
//

import Matrix
import Foundation

public extension Graph {

    /// The graph left after removing `other`'s edge weights from this graph's —
    /// a port of gstudio's `-.popgraph`.
    ///
    /// Element-wise on the undirected weighted adjacency: each retained edge's
    /// weight becomes `w_self − w_other` (0 when `other` lacks the edge), and
    /// any edge whose result is not positive is dropped. Node metadata is
    /// carried over from `self`.
    ///
    /// - Parameter other: A graph whose node set contains all of this graph's
    ///   nodes (matching gstudio's identical-node-set requirement).
    /// - Returns: The difference graph, or `nil` if either graph has no nodes
    ///   or `other` is missing one of this graph's nodes.
    func subtractingEdges(in other: Graph) -> Graph? {
        guard !nodes.isEmpty, !other.nodes.isEmpty else { return nil }

        let otherNames = Set(other.nodes.map { $0.name })
        guard Set(nodes.map { $0.name }).isSubset(of: otherNames) else { return nil }

        let otherAdjacency = other.undirectedAdjacency()

        let newNodes = nodes.map { source -> Node in
            let copy = Node(name: source.name, size: source.size, color: source.color,
                            categoricalAttributes: source.categoricalAttributes,
                            continuousAttributes: source.continuousAttributes)
            if let coordinate = source.coordinate { copy.coordinate = coordinate }
            return copy
        }
        let nodeByName = Dictionary(uniqueKeysWithValues: newNodes.map { ($0.name, $0) })

        var edges: [Edge] = []
        for edge in undirectedEdgeList() {
            let remaining = edge.weight - (otherAdjacency[edge.from]?[edge.to] ?? 0.0)
            guard remaining > 0 else { continue }
            guard let from = nodeByName[edge.from], let to = nodeByName[edge.to] else { continue }
            edges.append(Edge(fromNode: from, toNode: to, weight: remaining))
        }

        return Graph(nodes: newNodes, edges: edges)
    }
}
