//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IsolationByGraphDistance.swift
//  Graph
//
//  A port of gstudio's `ibgd()` (>= 1.15), split by mode because the two return
//  different kinds of result:
//    - IsolationByGraphDistance            <- ibgd(mode = "cgd"): cGD vs
//      separation, Mantel permutation test.
//    - DirectionalIsolationByGraphDistance <- ibgd(mode = "pgd"): does a
//      directed pGD model with forward/reverse slopes fit better than cGD?
//  See `~/Coding/gstudio/R/ibgd.R`.
//
//  Created by Rodney Dyer on 2026.10.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import Foundation

/// How populations are separated along the hypothesized axis, for
/// ``IsolationByGraphDistance(graph:separation:permutations:seed:)`` and
/// ``DirectionalIsolationByGraphDistance(graph:separation:gamma:)``.
public enum GraphSeparation {
    /// A position per node (keyed by node name). Separation is `|xⱼ − xᵢ|`; the
    /// ordered pair `(i, j)` is forward when `xⱼ > xᵢ`.
    case positions([String: Double])
    /// An `n × n` spatial (or resistance) distance matrix, in node order or with
    /// node row/column names. `forward` (non-zero = `true`) marks ordered pairs
    /// running in the hypothesized forward direction; it is required by the
    /// directional test and ignored by the cGD test.
    case distances(Matrix, forward: Matrix?)
}

/// The result of ``IsolationByGraphDistance(graph:separation:permutations:seed:)``
/// — the fields of gstudio's `ibgd(mode = "cgd")` `htest`.
public struct IsolationByGraphDistanceResult: Sendable, Equatable {
    /// Pearson `r` between cGD and separation over connected population pairs.
    public let statistic: Double
    /// One-sided Mantel p-value `(1 + #{r_null ≥ r_obs}) / (1 + B)`.
    public let pValue: Double
    /// Number of unordered population pairs used.
    public let pairs: Int
    /// Number of Mantel permutations.
    public let permutations: Int
    /// `r²`.
    public let r2: Double
    /// Least-squares slope of cGD on separation.
    public let slope: Double
}

/// The result of ``DirectionalIsolationByGraphDistance(graph:separation:gamma:)``
/// — the fields of gstudio's `ibgd(mode = "pgd")` `htest`. There is no p-value:
/// the two fits use different responses, so they are not nested.
public struct DirectionalIsolationByGraphDistanceResult: Sendable, Equatable {
    /// `ΔR² = adjusted R²_pGD − R²_cGD`. Positive favours the directional
    /// description; `≤ 0` is an absence of evidence for asymmetry, not evidence
    /// of symmetry.
    public let deltaR2: Double
    /// Number of ordered population pairs in the pGD fit.
    public let pairs: Int
    /// `R²` of cGD on separation.
    public let r2CGD: Double
    /// Adjusted `R²` of `pGD ~ d + d:reverse`.
    public let adjustedR2PGD: Double
    /// Slope for forward (downstream) pairs.
    public let forwardSlope: Double
    /// Slope for reverse (upstream) pairs.
    public let reverseSlope: Double
    /// `forwardSlope / reverseSlope`; below one means genetic distance
    /// accumulates more slowly downstream.
    public let slopeRatio: Double
    /// The pGD bandwidth multiplier used.
    public let gamma: Double
}

/// Isolation by graph distance (IBGD) — a port of gstudio's
/// `ibgd(mode = "cgd")`.
///
/// All-pairs conditional genetic distance (shortest-path distance over edge
/// weights) is correlated with separation over each unordered pair of connected
/// populations, and tested with a Mantel permutation test that permutes
/// populations' positions. With the same `seed` the permutations match R's
/// `set.seed(seed); ibgd(graph, ...)`.
///
/// - Parameters:
///   - graph: An undirected, weighted graph.
///   - separation: Positions or a distance matrix.
///   - permutations: Number of Mantel permutations (default `999`).
///   - seed: RNG seed, equivalent to R's `set.seed(seed)`.
/// - Returns: The test, or `nil` if the separation does not cover every node
///   or fewer than three pairs are connected.
public func IsolationByGraphDistance(graph: Graph,
                                     separation: GraphSeparation,
                                     permutations: Int = 999,
                                     seed: Int) -> IsolationByGraphDistanceResult? {
    guard let analysis = IsolationByGraphDistanceAnalysis(graph: graph, separation: separation),
          let outcome = analysis.run(options: AnalysisOptions(iterations: permutations,
                                                              seed: UInt64(truncatingIfNeeded: seed))),
          let slope = outcome.mantel.line?.slope else { return nil }
    return IsolationByGraphDistanceResult(statistic: outcome.statistic,
                                          pValue: outcome.pValue ?? 1,
                                          pairs: outcome.mantel.pairCount, permutations: permutations,
                                          r2: outcome.statistic * outcome.statistic,
                                          slope: slope)
}

/// Directional isolation by graph distance — a port of gstudio's
/// `ibgd(mode = "pgd")`.
///
/// All-pairs directed pGD (``PartitionedGeneticDistance(graph:gamma:)``) is
/// regressed on separation with separate forward and reverse slopes,
/// `pGDᵢⱼ ~ dᵢⱼ + dᵢⱼ·rᵢⱼ` (`rᵢⱼ = 1` for reverse pairs), and its adjusted `R²`
/// compared with the `R²` of cGD on separation. Deterministic.
///
/// - Parameters:
///   - graph: An undirected, weighted graph.
///   - separation: Positions, or a distance matrix *with* `forward`.
///   - gamma: Bandwidth multiplier for pGD (default `0.5`).
/// - Returns: The comparison, or `nil` if the separation does not cover every
///   node, a distance matrix lacks `forward`, `gamma` is invalid, or the
///   regression is singular or has too few pairs.
public func DirectionalIsolationByGraphDistance(graph: Graph,
                                                separation: GraphSeparation,
                                                gamma: Double = 0.5) -> DirectionalIsolationByGraphDistanceResult? {
    DirectionalIsolationByGraphDistanceAnalysis(graph: graph, separation: separation, gamma: gamma)?
        .run(options: AnalysisOptions(iterations: 0))?
        .result
}

// MARK: - Internals

/// Separation `X[i][j]` and (when available) the forward indicator, in node order.
func separationGeometry(_ graph: Graph, _ separation: GraphSeparation,
                                needsForward: Bool) -> (X: [[Double]], forward: [[Bool]]?)? {
    let names = graph.nodes.map { $0.name }
    let n = names.count
    switch separation {
    case .positions(let x):
        guard names.allSatisfy({ x[$0] != nil }) else { return nil }
        let xv = names.map { x[$0]! }
        let X = (0..<n).map { i in (0..<n).map { j in abs(xv[i] - xv[j]) } }
        let forward = (0..<n).map { i in (0..<n).map { j in xv[j] > xv[i] } }
        return (X, forward)
    case .distances(let distance, let forwardMatrix):
        guard let D = reorder(distance, to: names) else { return nil }
        let X = (0..<n).map { i in (0..<n).map { j in D[i, j] } }
        guard let forwardMatrix else { return needsForward ? nil : (X, nil) }
        guard let F = reorder(forwardMatrix, to: names) else { return nil }
        return (X, (0..<n).map { i in (0..<n).map { j in F[i, j] != 0 } })
    }
}

/// `matrix` in `names` order: as-is if unnamed, otherwise indexed by its
/// row/column names (R's `X[nodes, nodes]`). `nil` if the size or names don't fit.
private func reorder(_ matrix: Matrix, to names: [String]) -> Matrix? {
    let n = names.count
    guard matrix.rows == n, matrix.cols == n else { return nil }
    // An unnamed Matrix carries empty-string names.
    guard matrix.rowNames.allSatisfy({ !$0.isEmpty }), matrix.colNames.allSatisfy({ !$0.isEmpty }) else {
        return matrix
    }
    let rows = names.compactMap { matrix.rowNames.firstIndex(of: $0) }
    let cols = names.compactMap { matrix.colNames.firstIndex(of: $0) }
    guard rows.count == n, cols.count == n else { return nil }
    return matrix.submatrix(rows, cols)
}
