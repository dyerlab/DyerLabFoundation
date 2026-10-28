//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AsymmetryCI.swift
//  PopulationGenetics
//
//  A port of gstudio's `asymmetry_ci()` — a within-stratum bootstrap
//  confidence interval on each edge's asymmetry index, for reporting its
//  magnitude (an estimate, not a hypothesis test). Replaces the former
//  `asymmetry_jackknife()`. See `~/Coding/gstudio/R/asymmetry_ci.R`.
//
//  Created by Rodney Dyer on 2026.10.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import Graph
import Foundation

/// One edge's bootstrap interval from
/// ``AsymmetryCI(graph:data:groups:resamples:confidence:pendants:tol:seed:)`` —
/// mirrors a row of gstudio's `asymmetry_ci()` table.
public struct EdgeAsymmetryInterval: Sendable, Equatable {
    /// Edge's first endpoint (`Graph.undirectedEdgeList()` order).
    public let from: String
    /// Edge's second endpoint.
    public let to: String
    /// Observed asymmetry index `Δ`.
    public let delta: Double
    /// Mean resampled `Δ` over the resamples containing this edge (`boot_mean`),
    /// `.nan` if it never reappeared.
    public let bootMean: Double
    /// Lower percentile bound (`conf.low`), `.nan` if the edge never reappeared.
    public let confLow: Double
    /// Upper percentile bound (`conf.high`).
    public let confHigh: Double
    /// Proportion of successful resamples in which the edge was re-estimated
    /// (`edge_support`). The interval is conditional on the edge being present.
    public let edgeSupport: Double
}

/// The result of ``AsymmetryCI(graph:data:groups:resamples:confidence:pendants:tol:seed:)``.
public struct AsymmetryCIResult: Sendable {
    /// One row per retained edge.
    public let rows: [EdgeAsymmetryInterval]
    /// Pendant-incident edges dropped (`.drop`) or flagged (`.warn`); `nil` when
    /// there are none or with `.keep`.
    public let pendantEdgeCount: Int?
    /// Confidence level used (`attr(, "conf")`).
    public let confidence: Double
    /// Bootstrap resamples requested (`attr(, "nboot")`).
    public let resamples: Int
    /// Resamples that failed to produce a graph and were excluded from both the
    /// intervals and `edgeSupport` (`attr(, "nboot_failed")`).
    public let failedResamples: Int
}

/// Bootstrap confidence intervals for edge asymmetry — a port of gstudio's
/// `asymmetry_ci()`.
///
/// Individuals are resampled with replacement within each stratum, the
/// population graph and its asymmetries are re-estimated
/// (``PopulationGraph(x:groups:alpha:tol:)`` at its default `alpha`), and a
/// percentile interval is formed for every observed edge. An observed edge may
/// be absent from a given resample — that resample then contributes nothing to
/// the edge's interval but counts against its `edgeSupport`. Resampled edges are
/// matched to observed edges by unordered endpoint pair and sign-corrected to
/// the observed orientation. With the same `seed`, this reproduces R's
/// `set.seed(seed); asymmetry_ci(graph, data, groups, nboot, conf)` (stratum
/// resampling runs in ascending stratum-name order, matching R's `split()` on a
/// `factor(as.character(groups))`).
///
/// - Parameters:
///   - graph: The observed population graph, which fixes the edge set and
///     each edge's `(from, to)` orientation.
///   - data: The same multivariate matrix `graph` was built from.
///   - groups: The same per-row stratum labels `graph` was built from.
///   - resamples: Number of within-stratum bootstrap resamples (default `999`).
///   - confidence: Confidence level, strictly between 0 and 1 (default `0.95`).
///   - pendants: Leaf-edge handling (default `.warn`).
///   - tol: Tolerance passed through to each re-estimated graph (default
///     `1.0e-4`, matching `PopulationGraph(x:groups:alpha:tol:)`).
///   - seed: RNG seed, equivalent to R's `set.seed(seed)`.
/// - Returns: The per-edge intervals, or `nil` if `confidence` is out of range,
///   `groups` lacks individuals for some graph node,
///   `GraphAsymmetries(graph:bandwidth:scale:)` cannot be computed for
///   `graph`, or no resample produced a valid graph (gstudio stops in each case).
public func AsymmetryCI(graph: Graph,
                        data: Matrix,
                        groups: [String],
                        resamples: Int = 999,
                        confidence: Double = 0.95,
                        pendants: PendantHandling = .warn,
                        tol: Double = 1.0e-4,
                        seed: Int) -> AsymmetryCIResult? {
    guard confidence > 0, confidence < 1,
          groupsCoverGraph(graph, groups),
          let observed = GraphAsymmetries(graph: graph) else { return nil }

    let edgeList = graph.undirectedEdgeList()
    let observedDelta = observed.edges.map { $0.delta }
    let obsKeys = edgeList.map { unorderedEdgeKey($0.from, $0.to) }

    var strataIndices: [String: [Int]] = [:]
    for (index, group) in groups.enumerated() {
        strataIndices[group, default: []].append(index)
    }
    let strataOrder = Array(Set(groups)).sorted()                              // R: split() on a sorted factor

    var samples = [[Double]](repeating: [], count: edgeList.count)
    var succeeded = 0
    var rng = RMersenneTwister(seed: seed)

    for _ in 0..<resamples {
        // R: ii[sample.int(length(ii), replace = TRUE)] — also correct for a
        // single-individual stratum.
        var idx: [Int] = []
        idx.reserveCapacity(groups.count)
        for stratum in strataOrder {
            let ii = strataIndices[stratum] ?? []
            idx.append(contentsOf: rng.sample(ii, size: ii.count, replace: true))
        }

        let idxGroups = idx.map { groups[$0] }
        let idxData = data.submatrix(idx, Array(0..<data.cols))

        guard let nullGraph = PopulationGraph(x: idxData, groups: idxGroups, tol: tol),
              let nullAsym = GraphAsymmetries(graph: nullGraph) else { continue }
        succeeded += 1

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

    guard succeeded > 0 else { return nil }

    let tail = (1.0 - confidence) / 2.0
    let rows = edgeList.indices.map { i -> EdgeAsymmetryInterval in
        let values = samples[i]
        return EdgeAsymmetryInterval(
            from: edgeList[i].from, to: edgeList[i].to,
            delta: observedDelta[i],
            bootMean: values.isEmpty ? .nan : values.reduce(0, +) / Double(values.count),
            confLow: values.isEmpty ? .nan : empiricalQuantile(values, probability: tail),
            confHigh: values.isEmpty ? .nan : empiricalQuantile(values, probability: 1.0 - tail),
            edgeSupport: Double(values.count) / Double(succeeded))
    }

    let (kept, pendantCount) = handlePendantEdges(rows, graph: graph, pendants: pendants,
                                                  endpoints: { ($0.from, $0.to) })
    return AsymmetryCIResult(rows: kept, pendantEdgeCount: pendantCount,
                             confidence: confidence, resamples: resamples,
                             failedResamples: resamples - succeeded)
}
