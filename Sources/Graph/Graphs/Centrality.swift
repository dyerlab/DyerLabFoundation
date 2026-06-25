//
//  Centrality.swift
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

/// Computes out-degree centrality for all nodes.
///
/// Out-degree centrality counts the number of outgoing edges from each node.
///
/// - Parameter graph: The graph to analyze
/// - Returns: A vector where element i is the out-degree of node i
///
/// ## Example
/// ```swift
/// let g = Graph.smallGraph
/// let outDegree = OutDegreeCentrality(graph: g)
/// print("Node 0 has \(outDegree[0]) outgoing edges")
/// ```
public func OutDegreeCentrality( graph: Graph ) -> Vector {
    var ret = Vector(repeating: 0.0, count: graph.cardinality )
    for edge in graph.edges {
        if let idx = graph.nodes.firstIndex(where: { $0.id == edge.fromNode } ) {
            ret[idx] += 1.0
        }
    }
    return ret
}

/// Computes in-degree centrality for all nodes.
///
/// In-degree centrality counts the number of incoming edges to each node.
///
/// - Parameter graph: The graph to analyze
/// - Returns: A vector where element i is the in-degree of node i
public func InDegreeCentrality( graph: Graph ) -> Vector {
    var ret = Vector(repeating: 0.0, count: graph.cardinality )
    for edge in graph.edges {
        if let idx = graph.nodes.firstIndex(where: { $0.id == edge.toNode } ) {
            ret[idx] += 1.0
        }
    }
    return ret
}

/// Computes total degree centrality for all nodes.
///
/// Total degree is the sum of in-degree and out-degree for each node.
///
/// - Parameter graph: The graph to analyze
/// - Returns: A vector where element i is the total degree of node i
public func TotalDegreeCentrality( graph: Graph ) -> Vector {
    return OutDegreeCentrality(graph: graph) + InDegreeCentrality(graph: graph)
}




/// Computes closeness centrality for all nodes.
///
/// Closeness centrality measures how close a node is to all other reachable nodes.
/// Computed as the inverse of the average shortest path distance.
///
/// - Parameter graph: The graph to analyze
/// - Returns: A vector where element i is the closeness centrality of node i
///
/// Nodes with no reachable nodes have centrality 0.
///
/// ## Formula
/// For node i: `C(i) = (# reachable nodes) / (sum of distances to reachable nodes)`
public func ClosenessCentrality(graph: Graph) -> Vector {
    let n = graph.cardinality
    var ret = Vector(repeating: 0.0, count: n)

    for (i, source) in graph.nodes.enumerated() {
        var totalDistance = 0.0
        var reachableCount = 0

        for (j, target) in graph.nodes.enumerated() {
            if i == j { continue }
            if let path = graph.shortestPath(from: source, to: target) {
                totalDistance += path.distance
                reachableCount += 1
            }
        }

        if totalDistance > 0.0 && reachableCount > 0 {
            ret[i] = Double(reachableCount) / totalDistance
        } else {
            ret[i] = 0.0
        }
    }

    return ret
}





/// Computes betweenness centrality for all nodes.
///
/// Betweenness centrality measures how often a node appears on shortest paths
/// between other node pairs. Nodes with high betweenness act as "bridges" in the network.
///
/// - Parameter graph: The graph to analyze
/// - Returns: A vector of normalized betweenness scores (range: 0 to 1)
///
/// ## Formula
/// For node k: counts how many shortest paths from i to j pass through k,
/// normalized by (n-1)(n-2) where n is the number of nodes.
public func BetweennessCentrality(graph: Graph) -> Vector {
    let n = graph.cardinality
    var ret = Vector(repeating: 0.0, count: n)

    for i in 0..<n {
        for j in 0..<n {
            if i == j { continue }
            guard let path = graph.shortestPath(from: graph.nodes[i], to: graph.nodes[j]) else { continue }

            for (k, node) in graph.nodes.enumerated() {
                if k != i && k != j && path.sequence.contains(where: { $0.id == node.id }) {
                    ret[k] += 1.0
                }
            }
        }
    }

    // Normalize (optional)
    let scale = Double((n - 1) * (n - 2))
    if scale > 0 {
        for i in 0..<n {
            ret[i] /= scale
        }
    }

    return ret
}


/// Computes eigenvector centrality for all nodes.
///
/// Eigenvector centrality assigns importance based on the importance of neighbors.
/// A node connected to high-centrality nodes gets higher centrality.
///
/// Uses power iteration on the weighted adjacency matrix to find the dominant eigenvector.
///
/// - Parameter graph: The graph to analyze
/// - Returns: A vector of normalized centrality scores, or `nil` if:
///   - The graph is empty
///   - The adjacency matrix has no positive eigenvalues
///   - Power iteration fails to converge
///
/// ## Example
/// ```swift
/// let g = Graph.lophoGraph
/// if let centrality = EigenvectorCentrality(graph: g) {
///     let maxIdx = centrality.enumerated().max(by: { $0.1 < $1.1 })?.0
///     print("Most central node:", g.nodes[maxIdx!].name)
/// }
/// ```
///
/// - Note: May return `nil` for disconnected graphs or graphs with certain topologies.
public func EigenvectorCentrality(graph: Graph) -> Vector?  {
    let A = AdjacencyMatrix(graph: graph, weighed: true)
    let n = A.rows
    guard n > 0 && A.cols == n else { return nil }

    // Add a self-loop (identity shift: A → A + I) so the dominant eigenvalue is
    // unique. Bipartite/periodic graphs (e.g. a star) have eigenvalues ±λ of
    // equal magnitude, which makes plain power iteration oscillate and never
    // converge. The shift breaks that tie while leaving the eigenvectors —
    // and therefore the centrality ranking — unchanged.
    for i in 0..<n {
        A[i, i] += 1.0
    }

    var b_k = Vector(repeating: 1.0, count: n)
    let maxIterations = 1000
    let tolerance = 1e-6
    
    for _ in 0..<maxIterations {
        let b_k1 = A .* b_k
        // Normalize by the scalar L2 norm (magnitude), not the unit vector.
        let norm = b_k1.magnitude
        if norm == 0.0 {
            return nil
        }
        let b_k1_normalized = b_k1 / norm
        // Convergence: L2 distance between successive normalized estimates.
        let diff = euclideanDistance(b_k1_normalized, b_k)
        b_k = b_k1_normalized
        if diff < tolerance {
            break
        }
    }
    
    return b_k
}
