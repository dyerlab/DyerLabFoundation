//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AsymmetryJackknife.swift
//  PopulationGenetics
//
//  A port of gstudio's `asymmetry_jackknife()` — a within-stratum bootstrap
//  stability test for edge asymmetry. See
//  `~/Coding/gstudio/R/asymmetry_jackknife.R`.
//

import Matrix
import Graph
import Foundation

/// Stability (bootstrap) test for edge asymmetry — a port of gstudio's
/// `asymmetry_jackknife()`.
///
/// Individuals are resampled with replacement within each stratum, the
/// population graph and its asymmetries are re-estimated
/// (``PopulationGraph(x:groups:alpha:tol:)`` at its default `alpha`), and a
/// resampling confidence interval is formed for every observed edge. Because
/// the graph is re-estimated on each resample, an observed edge may be absent
/// from a given resample — that resample simply contributes nothing to the
/// edge's interval. Resampled edges are matched to observed edges by
/// unordered endpoint pair and sign-corrected to the observed orientation.
/// With the same `seed`, this reproduces R's
/// `set.seed(seed); asymmetry_jackknife(graph, data, groups, nperm, conf)`
/// exactly (stratum resampling runs in ascending stratum-name order, matching
/// R's `split()` on a `factor(as.character(groups))`).
///
/// - Parameters:
///   - graph: The observed population graph, which fixes the edge set and
///     each edge's `(from, to)` orientation.
///   - data: The same multivariate matrix `graph` was built from.
///   - groups: The same per-row stratum labels `graph` was built from.
///   - permutations: Number of within-stratum bootstrap resamples (default `999`).
///   - confidence: Confidence level for the per-edge interval (default `0.95`).
///   - tol: Tolerance passed through to each re-estimated graph (default
///     `1.0e-4`, matching `PopulationGraph(x:groups:alpha:tol:)`).
///   - seed: RNG seed, equivalent to R's `set.seed(seed)`.
/// - Returns: One row per undirected edge of `graph` — `statistic` is the mean
///   resampled `Δ`, `pValue` is always `.nan` (this mode reports a CI, not a
///   p-value), and `ciLow`/`ciHigh`/`statistic` are `.nan` for an edge with no
///   surviving resamples — or `nil` if ``GraphAsymmetries(graph:bandwidth:scale:)``
///   cannot be computed for `graph`.
public func AsymmetryJackknifeTest(graph: Graph,
                                   data: Matrix,
                                   groups: [String],
                                   permutations: Int = 999,
                                   confidence: Double = 0.95,
                                   tol: Double = 1.0e-4,
                                   seed: Int) -> [EdgeAsymmetrySignificance]? {
    guard let observed = GraphAsymmetries(graph: graph) else { return nil }

    let edgeList = graph.undirectedEdgeList()
    let observedDelta = observed.edges.map { $0.delta }
    let obsKeys = edgeList.map { unorderedEdgeKey($0.from, $0.to) }

    var strataIndices: [String: [Int]] = [:]
    for (index, group) in groups.enumerated() {
        strataIndices[group, default: []].append(index)
    }
    let strataOrder = Array(Set(groups)).sorted()                              // R: split() on a sorted factor

    var samples = [[Double]](repeating: [], count: edgeList.count)
    var rng = RMersenneTwister(seed: seed)

    for _ in 0..<permutations {
        var idx: [Int] = []
        idx.reserveCapacity(groups.count)
        for stratum in strataOrder {
            let ii = strataIndices[stratum] ?? []
            idx.append(contentsOf: rng.sample(ii, size: ii.count, replace: true))
        }

        let idxGroups = idx.map { groups[$0] }
        let idxData = data.submatrix(idx, Array(0..<data.cols))

        guard let nullGraph = PopulationGraph(x: idxData, groups: idxGroups, tol: tol),
              !nullGraph.undirectedEdgeList().isEmpty,
              let nullAsym = GraphAsymmetries(graph: nullGraph) else { continue }

        var byKey: [String: DirectionalEdge] = [:]
        for edge in nullAsym.edges {
            byKey[unorderedEdgeKey(edge.from, edge.to)] = edge
        }

        for (index, key) in obsKeys.enumerated() {
            guard let edge = byKey[key] else { continue }
            let value = edge.from == edgeList[index].from ? edge.delta : -edge.delta
            samples[index].append(value)
        }
    }

    let tail = (1.0 - confidence) / 2.0
    return edgeList.indices.map { i in
        let values = samples[i]
        let statistic = values.isEmpty ? Double.nan : values.reduce(0, +) / Double(values.count)
        let ciLow = values.isEmpty ? Double.nan : EmpiricalQuantile(values, probability: tail)
        let ciHigh = values.isEmpty ? Double.nan : EmpiricalQuantile(values, probability: 1.0 - tail)
        return EdgeAsymmetrySignificance(
            from: edgeList[i].from, to: edgeList[i].to,
            delta: observedDelta[i], statistic: statistic,
            pValue: .nan, ciLow: ciLow, ciHigh: ciHigh)
    }
}
