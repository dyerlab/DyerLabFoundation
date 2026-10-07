//
//  IsolationByGraphDistance.swift
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
//  A port of gstudio's `ibgd()` (>= 1.15), split by mode because the two return
//  different kinds of result:
//    - IsolationByGraphDistance            <- ibgd(mode = "cgd"): cGD vs
//      separation, Mantel permutation test.
//    - DirectionalIsolationByGraphDistance <- ibgd(mode = "pgd"): does a
//      directed pGD model with forward/reverse slopes fit better than cGD?
//  See `~/Coding/gstudio/R/ibgd.R`.
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
    guard let geometry = separationGeometry(graph, separation, needsForward: false) else { return nil }
    let n = geometry.X.count
    let C = graph.weightedDistanceMatrix()
    let pairs = upperPairs(C, n)
    guard pairs.count >= 3 else { return nil }

    let cgd = pairs.map { C[$0.0, $0.1] }
    let separationValues = pairs.map { geometry.X[$0.0][$0.1] }
    let observed = pearsonCorrelation(cgd, separationValues)

    var rng = RMersenneTwister(seed: seed)
    var exceed = 0
    for _ in 0..<permutations {
        let idx = rng.sampleIndicesNoReplacement(n: n)                  // R: sample.int(n)
        let permuted = pairs.map { geometry.X[idx[$0.0]][idx[$0.1]] }
        if pearsonCorrelation(cgd, permuted) >= observed { exceed += 1 }
    }

    return IsolationByGraphDistanceResult(statistic: observed,
                                          pValue: Double(1 + exceed) / Double(1 + permutations),
                                          pairs: pairs.count, permutations: permutations,
                                          r2: observed * observed,
                                          slope: simpleSlope(response: cgd, predictor: separationValues))
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
    guard let geometry = separationGeometry(graph, separation, needsForward: true),
          let forward = geometry.forward,
          let P = PartitionedGeneticDistance(graph: graph, gamma: gamma) else { return nil }
    let n = geometry.X.count

    // cGD R², over unordered connected pairs (as the cGD test).
    let C = graph.weightedDistanceMatrix()
    let pairs = upperPairs(C, n)
    guard pairs.count >= 3 else { return nil }
    let rCGD = pearsonCorrelation(pairs.map { C[$0.0, $0.1] }, pairs.map { geometry.X[$0.0][$0.1] })

    // pGD fit over ordered pairs with a hypothesized direction (column-major, as R).
    var response: [Double] = []
    var design: [Double] = []
    for j in 0..<n {
        for i in 0..<n where i != j && P[i, j].isFinite && (forward[i][j] || forward[j][i]) {
            let d = geometry.X[i][j]
            let reverse = forward[i][j] ? 0.0 : 1.0
            response.append(P[i, j])
            design.append(contentsOf: [1.0, d, d * reverse])
        }
    }
    let count = response.count
    guard count > 3, let fit = linearModelFit(designMatrix: Matrix(count, 3, design), response: response) else {
        return nil
    }
    // summary.lm: adj R² = 1 − (1 − R²)(n − 1)/(n − p), intercept included.
    let adjusted = 1.0 - (1.0 - fit.r2) * Double(count - 1) / Double(count - 3)
    let forwardSlope = fit.coefficients[1]
    let reverseSlope = fit.coefficients[1] + fit.coefficients[2]
    let r2CGD = rCGD * rCGD
    return DirectionalIsolationByGraphDistanceResult(deltaR2: adjusted - r2CGD, pairs: count,
                                                     r2CGD: r2CGD, adjustedR2PGD: adjusted,
                                                     forwardSlope: forwardSlope, reverseSlope: reverseSlope,
                                                     slopeRatio: forwardSlope / reverseSlope, gamma: gamma)
}

// MARK: - Internals

/// Separation `X[i][j]` and (when available) the forward indicator, in node order.
private func separationGeometry(_ graph: Graph, _ separation: GraphSeparation,
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

/// Unordered pairs `(i, j)`, `i < j`, with finite distance — R's
/// `upper.tri(C) & is.finite(C)`, in its column-major order.
private func upperPairs(_ C: Matrix, _ n: Int) -> [(Int, Int)] {
    var pairs: [(Int, Int)] = []
    for j in 0..<n { for i in 0..<j where C[i, j].isFinite { pairs.append((i, j)) } }
    return pairs
}

/// Least-squares slope of `response` on `predictor` (`coef(lm(y ~ x))[2]`).
private func simpleSlope(response y: [Double], predictor x: [Double]) -> Double {
    let mx = x.reduce(0, +) / Double(x.count), my = y.reduce(0, +) / Double(y.count)
    let sxy = zip(x, y).reduce(0.0) { $0 + ($1.0 - mx) * ($1.1 - my) }
    let sxx = x.reduce(0.0) { $0 + ($1 - mx) * ($1 - mx) }
    return sxy / sxx
}
