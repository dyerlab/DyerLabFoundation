//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AsymmetryPermutation.swift
//  PopulationGenetics
//
//  A port of gstudio's `asymmetry_permutation()` — a fixed-topology
//  permutation null for edge asymmetry. See
//  `~/Coding/gstudio/R/asymmetry_permutation.R`.
//

import Matrix
import Graph
import Foundation

/// Fixed-topology permutation test for edge asymmetry — a port of gstudio's
/// `asymmetry_permutation()`.
///
/// The observed adjacency is held fixed; individual-to-stratum labels are
/// permuted, the full conditional-distance matrix is recomputed under the
/// permuted labels (`alpha = 1`, retaining every population pair via
/// ``PopulationGraphConditionalDistanceMatrix(x:groups:tol:)``), and each
/// OBSERVED edge reads its permuted weight from that matrix before `Δ` is
/// recalculated. Because the edge set never changes across permutations,
/// every retained edge gets a full, equally sized null distribution. With the
/// same `seed`, this reproduces R's
/// `set.seed(seed); asymmetry_permutation(graph, data, groups, nperm)` exactly.
///
/// - Parameters:
///   - graph: The observed population graph (`PopulationGraph(x:groups:...)`),
///     which fixes both the edge set and each edge's `(from, to)` orientation.
///   - data: The same multivariate matrix `graph` was built from.
///   - groups: The same per-row stratum labels `graph` was built from.
///   - permutations: Number of label permutations (default `999`).
///   - tol: Tolerance passed through to the re-estimated distance matrix
///     (default `1.0e-4`, matching `PopulationGraph(x:groups:alpha:tol:)`).
///   - seed: RNG seed, equivalent to R's `set.seed(seed)`.
/// - Returns: One row per undirected edge (``Graph/undirectedEdgeList()``
///   order), or `nil` if ``GraphAsymmetries(graph:bandwidth:scale:)`` cannot be
///   computed for `graph`.
///
/// - Note: Unlike gstudio, which has no `tryCatch` here and simply errors out
///   of the whole call, a permutation whose re-estimated distance matrix or
///   asymmetries cannot be computed (a numerically degenerate label draw) is
///   skipped rather than aborting the run — the same convention
///   ``AsymmetryNetworkTest(graph:permutations:rewire:seed:)`` uses for an
///   unreachable rewired draw. The p-value denominator is the number of
///   permutations that actually completed.
public func AsymmetryPermutationTest(graph: Graph,
                                     data: Matrix,
                                     groups: [String],
                                     permutations: Int = 999,
                                     tol: Double = 1.0e-4,
                                     seed: Int) -> [EdgeAsymmetrySignificance]? {
    guard let observed = GraphAsymmetries(graph: graph) else { return nil }

    let edgeList = graph.undirectedEdgeList()
    let observedDelta = observed.edges.map { $0.delta }
    let nodeNames = graph.nodes.map { $0.name }

    var greaterOrEqual = [Int](repeating: 0, count: observedDelta.count)
    var completed = 0
    var rng = RMersenneTwister(seed: seed)

    for _ in 0..<permutations {
        let permGroups = rng.sample(groups)                                    // R: sample(groups)
        guard let Wp = PopulationGraphConditionalDistanceMatrix(x: data, groups: permGroups, tol: tol) else { continue }

        let nullNodes = nodeNames.map { Node(name: $0, size: 1.0) }
        let nodeByName = Dictionary(uniqueKeysWithValues: zip(nodeNames, nullNodes))
        let nullEdges = edgeList.compactMap { edge -> Edge? in
            guard let weight = matrixValue(Wp, edge.from, edge.to),
                  let from = nodeByName[edge.from], let to = nodeByName[edge.to] else { return nil }
            return Edge(fromNode: from, toNode: to, weight: weight)
        }
        guard nullEdges.count == edgeList.count,
              let nullAsym = GraphAsymmetries(graph: Graph(nodes: nullNodes, edges: nullEdges)),
              nullAsym.edges.count == observedDelta.count else { continue }

        completed += 1
        for (index, edge) in nullAsym.edges.enumerated() where abs(edge.delta) >= abs(observedDelta[index]) {
            greaterOrEqual[index] += 1
        }
    }

    // Add-one (biased-up) permutation p-value: (1 + #{|null| >= |obs|}) / (1 + B).
    let denominator = 1.0 + Double(completed)
    return edgeList.indices.map { i in
        EdgeAsymmetrySignificance(
            from: edgeList[i].from, to: edgeList[i].to,
            delta: observedDelta[i], statistic: observedDelta[i],
            pValue: (1.0 + Double(greaterOrEqual[i])) / denominator,
            ciLow: nil, ciHigh: nil)
    }
}

/// The value at `(row, col)` in a matrix with string `rowNames`/`colNames`, or
/// `nil` if either name is absent.
func matrixValue(_ matrix: Matrix, _ row: String, _ col: String) -> Double? {
    guard let r = matrix.rowNames.firstIndex(of: row), let c = matrix.colNames.firstIndex(of: col) else { return nil }
    return matrix[r, c]
}

/// An order-independent key for an unordered node pair, for matching an edge
/// across two edge lists regardless of endpoint orientation.
func unorderedEdgeKey(_ a: String, _ b: String) -> String {
    a <= b ? "\(a)\r\(b)" : "\(b)\r\(a)"
}
