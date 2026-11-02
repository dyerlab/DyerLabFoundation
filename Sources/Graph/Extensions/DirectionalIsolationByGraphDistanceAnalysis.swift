//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DirectionalIsolationByGraphDistanceAnalysis.swift
//  Graph
//
//  The `Analysis` form of `DirectionalIsolationByGraphDistance(graph:...)`,
//  which now delegates here. The graph's cGD and pGD matrices are copied into
//  value types when the analysis is built, so it is `Sendable` although
//  `Graph` is not. There is no permutation test (the two fits use different
//  responses, so they are not nested), so `AnalysisOptions` is unused.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// Directional isolation by graph distance
/// (`AnalysisType.directionalIsolationByGraphDistance`), a port of gstudio's
/// `ibgd(mode = "pgd")`.
///
/// Directed pGD is regressed on separation with separate forward and reverse
/// slopes, `pGDᵢⱼ ~ dᵢⱼ + dᵢⱼ·rᵢⱼ` (`rᵢⱼ = 1` for reverse pairs), and its
/// adjusted `R²` compared with the `R²` of cGD on separation.
public struct DirectionalIsolationByGraphDistanceAnalysis: Analysis {

    /// `AnalysisType.directionalIsolationByGraphDistance`.
    public static let analysisType: AnalysisType = .directionalIsolationByGraphDistance

    /// The node names, in matrix order.
    public let names: [String]

    /// The pGD bandwidth multiplier.
    public let gamma: Double

    /// The separation's name.
    public let separationLabel: String

    /// The label for the outcome.
    public let tag: AnalysisTag

    /// Separation between nodes `i` and `j`.
    private let separation: [[Double]]

    /// Whether the ordered pair `(i, j)` runs in the forward direction.
    private let forward: [[Bool]]

    /// Conditional genetic distance; `Inf` between disconnected nodes.
    private let cgd: [[Double]]

    /// Directed partitioned genetic distance from `i` to `j`.
    private let pgd: [[Double]]

    /// Creates the analysis.
    ///
    /// - Parameters:
    ///   - graph: An undirected graph whose edge weights are genetic distances.
    ///   - separation: Positions, or a distance matrix *with* `forward`.
    ///   - gamma: Bandwidth multiplier for pGD (default `0.5`).
    ///   - separationLabel: The separation's name (default `"Separation"`).
    ///   - tag: The outcome's label (default
    ///     `AnalysisType.directionalIsolationByGraphDistance.tag`).
    /// - Returns: `nil` if the separation does not cover every node, a distance
    ///   matrix lacks `forward`, or `gamma` is invalid.
    public init?(graph: Graph,
                 separation: GraphSeparation,
                 gamma: Double = 0.5,
                 separationLabel: String = "Separation",
                 tag: AnalysisTag = AnalysisType.directionalIsolationByGraphDistance.tag) {
        guard let geometry = separationGeometry(graph, separation, needsForward: true),
              let forward = geometry.forward,
              let P = PartitionedGeneticDistance(graph: graph, gamma: gamma) else { return nil }
        let n = geometry.X.count
        let C = graph.weightedDistanceMatrix()
        self.names = graph.nodes.map(\.name)
        self.gamma = gamma
        self.separationLabel = separationLabel
        self.tag = tag
        self.separation = geometry.X
        self.forward = forward
        self.cgd = (0..<n).map { i in (0..<n).map { j in C[i, j] } }
        self.pgd = (0..<n).map { i in (0..<n).map { j in P[i, j] } }
    }

    /// Fits both models.
    ///
    /// - Parameter options: Not used; the fit is deterministic.
    /// - Returns: The comparison, or `nil` if fewer than three pairs are
    ///   connected, too few ordered pairs have a direction, or the
    ///   regression is singular.
    public func run(options: AnalysisOptions) -> DirectionalIsolationByGraphDistanceOutcome? {
        let n = names.count

        // cGD R², over unordered connected pairs (as the cGD test), column-major as R.
        var cgdValues: [Double] = []
        var cgdSeparation: [Double] = []
        for j in 0..<n {
            for i in 0..<j where cgd[i][j].isFinite {
                cgdValues.append(cgd[i][j])
                cgdSeparation.append(separation[i][j])
            }
        }
        guard cgdValues.count >= 3 else { return nil }
        let rCGD = pearsonCorrelation(cgdValues, cgdSeparation)

        // pGD fit over ordered pairs with a hypothesized direction (column-major, as R).
        var response: [Double] = []
        var design: [Double] = []
        var forwardPoints: [PairwisePoint] = []
        var reversePoints: [PairwisePoint] = []
        for j in 0..<n {
            for i in 0..<n where i != j && pgd[i][j].isFinite && (forward[i][j] || forward[j][i]) {
                let d = separation[i][j]
                let point = PairwisePoint(from: names[i], to: names[j], x: d, y: pgd[i][j])
                if forward[i][j] { forwardPoints.append(point) } else { reversePoints.append(point) }
                response.append(pgd[i][j])
                design.append(contentsOf: [1.0, d, forward[i][j] ? 0.0 : d])
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
        let result = DirectionalIsolationByGraphDistanceResult(deltaR2: adjusted - r2CGD, pairs: count,
                                                               r2CGD: r2CGD, adjustedR2PGD: adjusted,
                                                               forwardSlope: forwardSlope,
                                                               reverseSlope: reverseSlope,
                                                               slopeRatio: forwardSlope / reverseSlope,
                                                               gamma: gamma)
        return DirectionalIsolationByGraphDistanceOutcome(result: result, intercept: fit.coefficients[0],
                                                          forwardPoints: forwardPoints,
                                                          reversePoints: reversePoints,
                                                          separationLabel: separationLabel, tag: tag)
    }
}
