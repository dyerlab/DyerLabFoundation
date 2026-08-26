//
//  Adjacency.swift
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

/// Constructs an adjacency matrix from a graph.
///
/// - Parameters:
///   - graph: The graph to convert
///   - weighed: If `true`, uses edge weights; if `false`, uses 1 for all edges
/// - Returns: A K×K matrix where K is the number of nodes
///   - Element [i,j] is the weight of edge from node i to node j
///   - Zero indicates no edge
///   - Row and column names are set to node names
///
/// ## Example
/// ```swift
/// let g = Graph.smallGraph
/// let A = AdjacencyMatrix(graph: g, weighed: true)
/// print("Edge weight from node 0 to node 1:", A[0,1])
/// ```
public func AdjacencyMatrix( graph: Graph, weighed: Bool ) -> Matrix {
    let N = graph.cardinality
    let names = graph.nodes.compactMap( { $0.name } )
    let ret = Matrix(N, N, 0.0)
    ret.colNames = names
    ret.rowNames = names
    
    for edge in graph.edges {
        if let n1 = graph.node(id: edge.fromNode ),
           let n2 = graph.node(id: edge.toNode ),
           let idx1 = graph.nodes.firstIndex(of: n1),
           let idx2 = graph.nodes.firstIndex(of: n2) {
            if weighed {
                ret[idx1,idx2] = edge.weight
            } else {
                ret[idx1,idx2] = 1.0
            }
        }
    }

    return ret
}

extension Graph {

    /// Builds an undirected graph from a weighted adjacency matrix.
    ///
    /// One `Node` per row/column (named from `adjacency.rowNames`), and one
    /// `Edge` for every off-diagonal, non-zero entry with `i < j` — the
    /// inverse of `AdjacencyMatrix(graph:weighed:)`, and matching R/igraph's
    /// `graph_from_adjacency_matrix(mode="undirected", diag=FALSE)`.
    ///
    /// - Parameters:
    ///   - adjacency: A square matrix; row/column `i` is node `i`.
    ///   - weighted: If `true`, edge weights come from the matrix entries;
    ///     if `false`, every retained edge gets weight `1.0`.
    ///   - nodeSize: Per-node visual size, keyed by node index; defaults to
    ///     `1.0` for nodes not present in the dictionary.
    public convenience init(adjacency: Matrix, weighted: Bool = true, nodeSize: [Int: Double] = [:]) {
        let names = adjacency.rowNames
        let nodes = names.enumerated().map { index, name in
            Node(name: name, size: nodeSize[index] ?? 1.0)
        }

        var edges: [Edge] = []
        for i in 0..<adjacency.rows {
            for j in (i + 1)..<adjacency.cols {
                let value = adjacency[i, j]
                guard value != 0.0 else { continue }
                edges.append(Edge(fromNode: nodes[i], toNode: nodes[j], weight: weighted ? value : 1.0))
            }
        }

        self.init(nodes: nodes, edges: edges)
    }
}
