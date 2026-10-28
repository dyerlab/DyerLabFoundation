//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PermutePopgraph.swift
//  PopulationGenetics
//
//  A port of gstudio's `permute_popgraph()` — bootstrap edge-stability
//  support for a population graph's topology. See
//  `~/Coding/gstudio/R/permute_popgraph.R`.
//
//  Ported against a 2026-09-11 gstudio fix (>= 1.14.1): the original R
//  function resampled individuals per stratum via `sampling::strata(...,
//  method = "srswr")`, which requires its input pre-sorted by the
//  stratification column and paired the resampled rows with the ORIGINAL,
//  unsorted `groups` vector — a silent row-misalignment bug whenever the
//  input wasn't already stratum-sorted, and not bit-exact-portable without
//  reimplementing R's `rbinom`/`rmultinom` (BTPE). gstudio now resamples each
//  stratum with a plain `sample(idx, size, replace = TRUE)` (the same idiom
//  `asymmetry_ci()`, formerly `asymmetry_jackknife()`, already used), which is both correct for any input
//  order and exactly reproducible here via `RMersenneTwister`.
//
//  Created by Rodney Dyer on 2026.09.11.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import Graph
import Foundation

/// One edge's bootstrap stability — gstudio's `decorate_graph(orig, A)`
/// output flattened to a row per edge of the observed graph.
public struct EdgeStability: Sendable, Equatable {
    /// Edge's first endpoint.
    public let from: String
    /// Edge's second endpoint.
    public let to: String
    /// The observed edge weight (`PopulationGraph(x:groups:)`'s conditional
    /// distance) — unaffected by resampling.
    public let weight: Double
    /// Proportion of bootstrap resamples (`0...1`) in which this edge
    /// appeared in the re-estimated graph — its topological support.
    public let probability: Double
}

/// Bootstrap edge-stability test for a population graph's topology — a port
/// of gstudio's `permute_popgraph()`.
///
/// Individuals are resampled with replacement within each stratum, the
/// population graph is re-estimated on each resample
/// (``PopulationGraph(x:groups:alpha:tol:)`` at its default `alpha`), and
/// every OBSERVED edge's `probability` is the fraction of resamples in which
/// it reappeared (an edge absent from a resample simply doesn't increment its
/// count; an edge the resampled graph gains that wasn't in the observed graph
/// is not reported, matching R's `A * origA` masking). With the same `seed`,
/// this reproduces R's
/// `set.seed(seed); permute_popgraph(data, groups, nboot)` exactly (stratum
/// resampling runs in ascending stratum-name order, matching R's `split()` on
/// a `factor(as.character(groups))`).
///
/// - Parameters:
///   - data: The multivariate matrix `PopulationGraph(x:groups:)` was (or
///     would be) built from.
///   - groups: The per-row stratum label for each of `data`'s rows.
///   - bootstraps: Number of within-stratum bootstrap resamples (default `50`,
///     matching gstudio's `nboot`).
///   - seed: RNG seed, equivalent to R's `set.seed(seed)`.
/// - Returns: One row per edge of the observed population graph, or `nil` if
///   ``PopulationGraph(x:groups:alpha:tol:)`` cannot be computed for
///   `(data, groups)`.
///
/// - Note: Unlike gstudio, which has no `tryCatch` here and simply errors out
///   of the whole call, a resample whose re-estimated graph cannot be
///   computed (a numerically degenerate bootstrap draw) is skipped rather
///   than aborting the run — the same convention
///   ``AsymmetryCI(graph:data:groups:resamples:confidence:pendants:tol:seed:)``
///   uses. The probability denominator is the number of resamples that
///   actually completed.
public func PermutePopgraph(data: Matrix,
                            groups: [String],
                            bootstraps: Int = 50,
                            seed: Int) -> [EdgeStability]? {
    guard let graph = PopulationGraph(x: data, groups: groups) else { return nil }
    let edgeList = graph.undirectedEdgeList()

    var strataIndices: [String: [Int]] = [:]
    for (index, group) in groups.enumerated() {
        strataIndices[group, default: []].append(index)
    }
    let strataOrder = Array(Set(groups)).sorted()                              // R: split() on a sorted factor

    var hitCount: [String: Int] = [:]
    var completed = 0
    var rng = RMersenneTwister(seed: seed)

    for _ in 0..<bootstraps {
        var idx: [Int] = []
        idx.reserveCapacity(groups.count)
        for stratum in strataOrder {
            let ii = strataIndices[stratum] ?? []
            idx.append(contentsOf: rng.sample(ii, size: ii.count, replace: true))
        }

        let idxGroups = idx.map { groups[$0] }
        let idxData = data.submatrix(idx, Array(0..<data.cols))
        guard let bootGraph = PopulationGraph(x: idxData, groups: idxGroups) else { continue }

        completed += 1
        for edge in bootGraph.undirectedEdgeList() {
            hitCount[unorderedEdgeKey(edge.from, edge.to), default: 0] += 1
        }
    }

    guard completed > 0 else {
        return edgeList.map { EdgeStability(from: $0.from, to: $0.to, weight: $0.weight, probability: 0.0) }
    }
    let denominator = Double(completed)
    return edgeList.map { edge in
        let count = hitCount[unorderedEdgeKey(edge.from, edge.to)] ?? 0
        return EdgeStability(from: edge.from,
                             to: edge.to,
                             weight: edge.weight,
                             probability: Double(count) / denominator)
    }
}
