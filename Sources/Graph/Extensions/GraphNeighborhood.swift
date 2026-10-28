//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GraphNeighborhood.swift
//  Graph
//
//  Undirected-neighbourhood queries shared by the population-graph analysis
//  ports (`GraphAsymmetries`, `AsymmetricWeights`, `CongruenceTopology`,
//  `TestCongruence`, graph subtraction). Each treats the graph as undirected:
//  an edge `a → b` and an edge `b → a` describe the same connection, and a
//  parallel pair contributes a single undirected edge whose weight is taken
//  from the first edge encountered — matching R/igraph's handling of a
//  `popgraph` built with `graph_from_adjacency_matrix(mode = "undirected")`.
//
//  Created by Rodney Dyer on 2026.09.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import Foundation

public extension Graph {

    /// The graph's undirected edges as `(a, b, weight)` triples, keyed by node
    /// name, with each unordered pair reported once in `edges` iteration order.
    ///
    /// `a` is whichever endpoint appears first in the originating `Edge`, so
    /// for a graph built by `Graph(adjacency:)` the pair is always
    /// `(lower-index node, higher-index node)` — the same orientation R's
    /// `igraph::as_edgelist()` produces for the equivalent graph.
    func undirectedEdgeList() -> [(from: String, to: String, weight: Double)] {
        let names = nodeNameByID()
        var seen = Set<Set<String>>()
        var result: [(from: String, to: String, weight: Double)] = []
        for edge in edges {
            guard let a = names[edge.fromNode], let b = names[edge.toNode], a != b else { continue }
            let key: Set<String> = [a, b]
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append((from: a, to: b, weight: edge.weight))
        }
        return result
    }

    /// The undirected weight between two nodes by name, or `nil` if they are
    /// not adjacent.
    ///
    /// - Parameters:
    ///   - a: The first node's name.
    ///   - b: The second node's name.
    /// - Returns: The edge weight, or `nil` if the nodes aren't adjacent.
    func undirectedEdgeWeight(_ a: String, _ b: String) -> Double? {
        undirectedAdjacency()[a]?[b]
    }

    /// The names of a node's undirected neighbours, in ascending natural order.
    ///
    /// - Parameter name: The node's name.
    /// - Returns: The neighbours' names, or an empty array for an unknown node.
    func undirectedNeighbors(of name: String) -> [String] {
        (undirectedAdjacency()[name].map { Array($0.keys) } ?? []).sorted()
    }

    /// Weighted degree (igraph `strength()`): the sum of the weights of a
    /// node's incident undirected edges.
    ///
    /// - Parameter name: The node's name.
    /// - Returns: The weighted degree, or `0` for an unknown node.
    func undirectedStrength(of name: String) -> Double {
        (undirectedAdjacency()[name]?.values.reduce(0, +)) ?? 0.0
    }

    /// Topological degree: the number of a node's undirected neighbours.
    ///
    /// - Parameter name: The node's name.
    /// - Returns: The degree, or `0` for an unknown node.
    func undirectedDegree(of name: String) -> Int {
        undirectedAdjacency()[name]?.count ?? 0
    }

    /// The subgraph induced by `nodeNames` — every node in the list that exists
    /// in the graph, plus every undirected edge whose endpoints are both in the
    /// list. Node order follows `nodeNames`. Edge weights are preserved.
    ///
    /// - Parameter nodeNames: The nodes to keep, in output order.
    /// - Returns: A new graph with copies of the kept nodes.
    func inducedSubgraph(nodeNames: [String]) -> Graph {
        let keep = nodeNames.filter { node(name: $0) != nil }
        let keepSet = Set(keep)
        let newNodes = keep.map { original -> Node in
            let source = node(name: original)
            let copy = Node(name: original, size: source?.size ?? 1.0, color: source?.color ?? .red,
                            categoricalAttributes: source?.categoricalAttributes ?? [:],
                            continuousAttributes: source?.continuousAttributes ?? [:])
            if let coordinate = source?.coordinate { copy.coordinate = coordinate }
            return copy
        }
        let nodeByName = Dictionary(uniqueKeysWithValues: newNodes.map { ($0.name, $0) })

        var newEdges: [Edge] = []
        for edge in undirectedEdgeList() where keepSet.contains(edge.from) && keepSet.contains(edge.to) {
            guard let from = nodeByName[edge.from], let to = nodeByName[edge.to] else { continue }
            newEdges.append(Edge(fromNode: from, toNode: to, weight: edge.weight))
        }
        return Graph(nodes: newNodes, edges: newEdges)
    }

    /// All-pairs shortest-path distances over the undirected, edge-weighted
    /// graph — the equivalent of igraph's `distances()`. Row/column order and
    /// names follow `nodes`; unreachable pairs are `Double.infinity`; the
    /// diagonal is `0`.
    ///
    /// - Returns: An `n × n` distance matrix in node order.
    func weightedDistanceMatrix() -> Matrix {
        let order = nodes.map { $0.name }
        let adjacency = undirectedAdjacency()
        let n = order.count

        let result = Matrix(n, n, Double.infinity)
        result.rowNames = order
        result.colNames = order

        for (start, source) in order.enumerated() {
            var distance = [String: Double]()
            distance[source] = 0
            var visited = Set<String>()
            var frontier = Set(order)

            while let current = frontier.min(by: {
                (distance[$0] ?? .infinity) < (distance[$1] ?? .infinity)
            }) {
                let currentDistance = distance[current] ?? .infinity
                if currentDistance.isInfinite { break }
                frontier.remove(current)
                visited.insert(current)

                for (neighbor, weight) in adjacency[current] ?? [:] where !visited.contains(neighbor) {
                    let candidate = currentDistance + weight
                    if candidate < (distance[neighbor] ?? .infinity) {
                        distance[neighbor] = candidate
                    }
                }
            }

            for (end, target) in order.enumerated() {
                result[start, end] = start == end ? 0.0 : (distance[target] ?? .infinity)
            }
        }

        return result
    }

    // MARK: - Internals

    /// Symmetric name-keyed adjacency with undirected weights, each unordered
    /// pair taken from the first originating `Edge`.
    ///
    /// - Returns: Each node name mapped to its neighbours' names and edge weights.
    internal func undirectedAdjacency() -> [String: [String: Double]] {
        var adjacency: [String: [String: Double]] = [:]
        for node in nodes where adjacency[node.name] == nil {
            adjacency[node.name] = [:]
        }
        for edge in undirectedEdgeList() {
            adjacency[edge.from, default: [:]][edge.to] = edge.weight
            adjacency[edge.to, default: [:]][edge.from] = edge.weight
        }
        return adjacency
    }

    /// Maps each node id to its name for O(1) edge-endpoint resolution.
    ///
    /// - Returns: Node names keyed by node id.
    internal func nodeNameByID() -> [UUID: String] {
        Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.name) })
    }
}
