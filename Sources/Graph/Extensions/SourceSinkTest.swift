//
//  SourceSinkTest.swift
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
//  A port of gstudio's `source_sink_test()` (>= 1.15): Spearman r(S, x) between
//  genetic-gravity source-sink scores and a hypothesized covariate, against a
//  Moran spectral randomization null on the graph's own topology (default), a
//  plain permutation of S, or spectral randomization on a supplied adjacency.
//  See `~/Coding/gstudio/R/source_sink_test.R`.
//

import Matrix
import Foundation

/// The null distribution ``SourceSinkTest(graph:x:gamma:permutations:null:interior:edgeMargin:returnNull:seed:)``
/// compares `r(S, x)` against.
public enum SourceSinkNull {
    /// Moran spectral randomization of `S` on the graph's kernel-weighted
    /// adjacency `exp(−e² / 2b̄²)` (`b̄` the mean edge weight) — gstudio's
    /// default `null = "graph"`.
    case graph
    /// Plain permutation of `S` (`null = "permute"`).
    case permute
    /// Moran spectral randomization on a user-supplied `n × n` adjacency, in
    /// node order or with node row/column names (`null = "adjacency"`).
    case adjacency(Matrix)
}

/// The result of ``SourceSinkTest(graph:x:gamma:permutations:null:interior:edgeMargin:returnNull:seed:)``
/// — the fields of gstudio's `source_sink_test` `htest`.
public struct SourceSinkTestResult: Sendable {
    /// Observed Spearman `r(S, x)` over the tested nodes (`statistic`).
    /// Negative means sources at low values of `x`.
    public let statistic: Double
    /// Two-sided p-value `(1 + #{|r_null| ≥ |r_obs|}) / (1 + B)`.
    public let pValue: Double
    /// Number of nodes in the test (`parameter["nodes"]`).
    public let nodes: Int
    /// Number of null replicates (`parameter["nperm"]`).
    public let permutations: Int
    /// The degree share of `Δ` (`estimate`); report it with the test.
    public let degreeShare: Double
    /// The bandwidth multiplier used.
    public let gamma: Double
    /// The source-sink scores the test was computed from.
    public let scores: SourceSinkResult
    /// The null distribution of `r`, when requested with `returnNull: true`.
    public let nullDistribution: [Double]?
}

/// Source-sink gradient test — a port of gstudio's `source_sink_test()`.
///
/// Spearman's `r` between the source-sink scores `S`
/// (``SourceSinkScores(graph:gamma:x:)``) and a covariate `x` (e.g. position
/// along a hypothesized axis of flow), tested two-sided against a null that
/// preserves `S`'s spatial structure on the graph (Moran spectral
/// randomization) or, with `.permute`, against plain permutation. `S` values
/// within `1e-10 · max|S|` of their sorted neighbour are treated as tied before
/// ranking, so floating-point near-ties cannot change ranks.
///
/// With `.permute`, and with the spectral nulls on graphs whose Moran
/// eigenvalues are distinct, the null replicates match R's for the same seed;
/// with repeated eigenvalues they agree in distribution.
///
/// - Parameters:
///   - graph: An undirected, weighted graph.
///   - x: The covariate keyed by node name.
///   - gamma: Bandwidth multiplier for the scores (default `0.5`).
///   - permutations: Number of null replicates (default `999`).
///   - null: The null model (default `.graph`).
///   - interior: Test only interior nodes — degree > 1 and at least
///     `edgeMargin` from either end of `x` (default `false`).
///   - edgeMargin: Units of `x` trimmed at each end when `interior` (default `2`).
///   - returnNull: Keep the null distribution of `r` (default `false`).
///   - seed: RNG seed, equivalent to R's `set.seed(seed)`.
/// - Returns: The test, or `nil` if `x` omits a node, `gamma` is invalid, fewer
///   than 4 nodes remain for the test, the adjacency is the wrong size, or the
///   spectral basis cannot be formed.
public func SourceSinkTest(graph: Graph,
                           x: [String: Double],
                           gamma: Double = 0.5,
                           permutations: Int = 999,
                           null: SourceSinkNull = .graph,
                           interior: Bool = false,
                           edgeMargin: Double = 2,
                           returnNull: Bool = false,
                           seed: Int) -> SourceSinkTestResult? {
    guard let scores = SourceSinkScores(graph: graph, gamma: gamma) else { return nil }
    let names = graph.nodes.map { $0.name }
    guard names.allSatisfy({ x[$0] != nil }) else { return nil }
    let xv = names.map { x[$0]! }
    let n = names.count

    let S = mergeNearTies(scores.scores.map { $0.s })
    var keep = [Bool](repeating: true, count: n)
    if interior, let lo = xv.min(), let hi = xv.max() {
        keep = (0..<n).map { scores.scores[$0].degree > 1 && xv[$0] >= lo + edgeMargin && xv[$0] <= hi - edgeMargin }
    }
    let kept = (0..<n).filter { keep[$0] }
    guard kept.count >= 4 else { return nil }
    let xKept = kept.map { xv[$0] }
    let observed = spearmanCorrelation(kept.map { S[$0] }, xKept)

    var rng = RMersenneTwister(seed: seed)
    var draws: [[Double]] = []                                         // one length-n replicate per entry
    switch null {
    case .permute:
        draws = (0..<permutations).map { _ in rng.sample(S) }
    case .graph:
        // R: A[A > 0] <- exp(-A[A > 0]^2 / (2 * bbar^2)) on the symmetric
        // weighted adjacency, bbar = mean(E(graph)$weight).
        let edges = graph.undirectedEdgeList()
        let bbar = edges.reduce(0.0) { $0 + $1.weight } / Double(edges.count)
        let indexOf = Dictionary(uniqueKeysWithValues: names.enumerated().map { ($1, $0) })
        let kernel = Matrix(n, n, 0.0)
        for edge in edges where edge.weight > 0 {
            let i = indexOf[edge.from]!, j = indexOf[edge.to]!
            let value = exp(-edge.weight * edge.weight / (2.0 * bbar * bbar))
            kernel[i, j] = value
            kernel[j, i] = value
        }
        guard let replicates = MoranSpectralRandomization(S, weights: kernel, replicates: permutations,
                                                          using: &rng) else { return nil }
        draws = (0..<permutations).map { replicates.getCol(c: $0) }
    case .adjacency(let supplied):
        guard supplied.rows == n, supplied.cols == n else { return nil }
        var ordered = supplied
        // An unnamed Matrix carries empty-string names.
        if supplied.rowNames.allSatisfy({ !$0.isEmpty }) && supplied.colNames.allSatisfy({ !$0.isEmpty }) {
            let rowIndex = names.compactMap { supplied.rowNames.firstIndex(of: $0) }
            let colIndex = names.compactMap { supplied.colNames.firstIndex(of: $0) }
            guard rowIndex.count == n, colIndex.count == n else { return nil }
            ordered = supplied.submatrix(rowIndex, colIndex)
        }
        guard let replicates = MoranSpectralRandomization(S, weights: ordered, replicates: permutations,
                                                          using: &rng) else { return nil }
        draws = (0..<permutations).map { replicates.getCol(c: $0) }
    }

    let nullR = draws.map { draw in spearmanCorrelation(kept.map { draw[$0] }, xKept) }
    let exceed = nullR.filter { abs($0) >= abs(observed) - 1e-12 }.count
    return SourceSinkTestResult(statistic: observed,
                                pValue: Double(1 + exceed) / Double(permutations + 1),
                                nodes: kept.count, permutations: permutations,
                                degreeShare: scores.degreeShare, gamma: gamma, scores: scores,
                                nullDistribution: returnNull ? nullR : nil)
}

/// gstudio's `.merge_ties()`: sorted values closer than `tolerance · max|z|` to
/// their predecessor take the first value of their run.
func mergeNearTies(_ z: [Double], tolerance: Double = 1e-10) -> [Double] {
    let finite = z.indices.filter { z[$0].isFinite }
    guard finite.count >= 2 else { return z }
    let order = finite.sorted { z[$0] < z[$1] }                        // R's order() is stable
    let sorted = order.map { z[$0] }
    let maxAbs = sorted.map { abs($0) }.max() ?? 0
    var result = z
    var runValue = sorted[0]
    for (position, index) in order.enumerated() {
        if position > 0 && sorted[position] - sorted[position - 1] > tolerance * maxAbs {
            runValue = sorted[position]
        }
        result[index] = runValue
    }
    return result
}
