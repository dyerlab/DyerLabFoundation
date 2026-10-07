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
/// `asymmetry_permutation()` (`asymmetry_significance(mode = "location")`).
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
/// With the topology fixed, each edge's null is centred on its topological
/// component (roughly `1/kᵢ − 1/kⱼ`), not on zero, so the test is two-sided
/// about the per-edge null mean: `statistic = Δ_obs − mean(null)` and
/// `p = (1 + #{|null − mean| ≥ |statistic|}) / (1 + B)` (gstudio ≥ 1.14.5).
///
/// - Parameters:
///   - graph: The observed population graph (`PopulationGraph(x:groups:...)`),
///     which fixes both the edge set and each edge's `(from, to)` orientation.
///   - data: The same multivariate matrix `graph` was built from.
///   - groups: The same per-row stratum labels `graph` was built from.
///   - permutations: Number of label permutations (default `999`).
///   - tol: Tolerance passed through to the re-estimated distance matrix
///     (default `1.0e-4`, matching `PopulationGraph(x:groups:alpha:tol:)`).
///   - returnNull: Keep each edge's null distribution on its row (default `false`).
///   - seed: RNG seed, equivalent to R's `set.seed(seed)`.
/// - Returns: One row per undirected edge (``Graph/undirectedEdgeList()``
///   order), or `nil` if ``GraphAsymmetries(graph:bandwidth:scale:)`` cannot be
///   computed for `graph` or `groups` lacks individuals for some graph node.
///
/// - Note: As in gstudio, a permutation whose re-estimated distance matrix or
///   asymmetries cannot be computed is dropped from the null; `B` is the number
///   of permutations that completed.
public func AsymmetryPermutationTest(graph: Graph,
                                     data: Matrix,
                                     groups: [String],
                                     permutations: Int = 999,
                                     tol: Double = 1.0e-4,
                                     returnNull: Bool = false,
                                     seed: Int) -> [EdgeAsymmetrySignificance]? {
    guard groupsCoverGraph(graph, groups), let observed = GraphAsymmetries(graph: graph) else { return nil }

    let edgeList = graph.undirectedEdgeList()
    let observedDelta = observed.edges.map { $0.delta }
    let nodeNames = graph.nodes.map { $0.name }

    var nulls = [[Double]](repeating: [], count: observedDelta.count)
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

        for (index, edge) in nullAsym.edges.enumerated() {
            nulls[index].append(edge.delta)
        }
    }

    // Add-one (biased-up) permutation p-value, centred on each edge's null mean:
    // (1 + #{|null - centre| >= |obs - centre|}) / (1 + B).
    return edgeList.indices.map { i in
        let null = nulls[i]
        let centre = null.isEmpty ? Double.nan : null.reduce(0, +) / Double(null.count)
        let statistic = observedDelta[i] - centre
        let exceedances = null.filter { abs($0 - centre) >= abs(statistic) }.count
        return EdgeAsymmetrySignificance(
            from: edgeList[i].from, to: edgeList[i].to,
            delta: observedDelta[i], statistic: statistic,
            pValue: (1.0 + Double(exceedances)) / (1.0 + Double(null.count)),
            nullDistribution: returnNull ? null : nil)
    }
}

/// gstudio's `.validate_asymmetry_groups()`: every graph node must be a stratum
/// in `groups`, or resampled graphs can never be matched to the observed edges.
func groupsCoverGraph(_ graph: Graph, _ groups: [String]) -> Bool {
    let strata = Set(groups)
    return graph.nodes.allSatisfy { strata.contains($0.name) }
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
