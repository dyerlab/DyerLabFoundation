//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IsolationByGraphDistanceAnalysis.swift
//  Graph
//
//  The `Analysis` form of `IsolationByGraphDistance(graph:...)`. It copies
//  the graph's cGD matrix and the separation into value types when built, so
//  it is `Sendable` although `Graph` is not.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// Isolation by graph distance (`AnalysisType.isolationByGraphDistance`):
/// cGD against separation with a Mantel test, a port of gstudio's
/// `ibgd(mode = "cGD")`.
public struct IsolationByGraphDistanceAnalysis: Analysis {

    /// `AnalysisType.isolationByGraphDistance`.
    public static let analysisType: AnalysisType = .isolationByGraphDistance

    /// The separation's name.
    public let separationLabel: String

    /// The label for the outcome.
    public let tag: AnalysisTag

    /// The Mantel test of cGD on separation.
    let mantel: MantelAnalysis

    /// Creates the analysis.
    ///
    /// - Parameters:
    ///   - graph: An undirected graph whose edge weights are genetic distances.
    ///   - separation: Positions or a distance matrix. A node with no finite separation to any other (a stratum
    ///     with no known position) is left out of the test, though paths between the others still pass through it.
    ///   - separationLabel: The separation's name (default `"Separation"`).
    ///   - tag: The outcome's label (default `AnalysisType.isolationByGraphDistance.tag`).
    ///   - method: The Mantel correlation (default Pearson, as gstudio's `ibgd()` uses).
    /// - Returns: `nil` if the separation does not cover every node or fewer
    ///   than three pairs are connected.
    public init?(graph: Graph,
                 separation: GraphSeparation,
                 separationLabel: String = "Separation",
                 tag: AnalysisTag = AnalysisType.isolationByGraphDistance.tag,
                 method: CorrelationMethod = .pearson) {
        guard let geometry = separationGeometry(graph, separation, needsForward: false) else { return nil }
        let n = geometry.X.count
        let X = geometry.X
        let C = graph.weightedDistanceMatrix()
        let placed = (0..<n).filter { i in (0..<n).contains { j in j != i && X[i][j].isFinite } }
        // Disconnected pairs have Inf cGD, which MantelAnalysis leaves out.
        guard var mantel = MantelAnalysis(response: placed.map { i in placed.map { j in C[i, j] } },
                                          predictor: placed.map { i in placed.map { j in X[i][j] } },
                                          names: placed.map { graph.nodes[$0].name },
                                          method: method,
                                          tag: tag) else { return nil }
        mantel.responseLabel = "conditional genetic distance"
        mantel.predictorLabel = AnalysisReport.sentenceCase(separationLabel)
        mantel.unitLabel = "populations"
        self.mantel = mantel
        self.separationLabel = separationLabel
        self.tag = tag
    }

    /// Runs the Mantel test.
    ///
    /// - Parameter options: Permutation count and seed (R's `set.seed()` value).
    /// - Returns: The outcome; never `nil`.
    public func run(options: AnalysisOptions) -> IsolationByGraphDistanceOutcome? {
        run(options: options) { _, _ in true }
    }

    /// Runs the Mantel test, reporting each permuted correlation.
    ///
    /// - Parameters:
    ///   - options: The permutations and seed.
    ///   - observing: Called after each permutation with the number done and the permuted correlation; return
    ///     `false` to stop, which finishes the test with the permutations drawn.
    /// - Returns: The test, or `nil` if it can't be run.
    public func run(options: AnalysisOptions,
                    observing: (_ done: Int, _ value: Double) -> Bool) -> IsolationByGraphDistanceOutcome? {
        mantel.run(options: options, observing: observing).map {
            IsolationByGraphDistanceOutcome(mantel: $0, separationLabel: separationLabel)
        }
    }
}
