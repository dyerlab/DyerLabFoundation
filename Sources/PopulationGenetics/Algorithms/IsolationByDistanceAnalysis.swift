//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IsolationByDistanceAnalysis.swift
//  PopulationGenetics
//
//  Rousset's (1997) isolation by distance: pairwise differentiation
//  linearized as `F / (1 − F)`, regressed on separation (log separation for a
//  two-dimensional habitat), with significance from a Mantel test. Single-
//  locus θ and multilocus Φ_ST are the same statistic, so either
//  `PairwisePhiST` matrix serves; only the label differs.
//
//  A pair with `F ≥ 1` has no finite linearization and is left out of the
//  test, as Mantel leaves out any non-finite response.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix

/// Isolation by distance between strata (`AnalysisType.isolationByDistance`).
///
/// ## Usage
///
/// ```swift
/// let phi = PairwisePhiST(distance: distances, strata: strata)
/// let km = pairwiseGreatCircleDistance(locations: centroids)
/// if let ibd = IsolationByDistanceAnalysis(differentiation: phi, separation: km, logSeparation: true),
///    let outcome = ibd.run(options: AnalysisOptions(iterations: 999, seed: 42)) {
///     print(outcome.statistic, outcome.pValue ?? .nan, outcome.slope ?? .nan)
/// }
/// ```
public struct IsolationByDistanceAnalysis: Analysis {

    /// `AnalysisType.isolationByDistance`.
    public static let analysisType: AnalysisType = .isolationByDistance

    /// Whether separation is log-transformed.
    public let logSeparation: Bool

    /// The differentiation measure's name.
    public let differentiationLabel: String

    /// The separation's name.
    public let separationLabel: String

    /// The label for the outcome.
    public let tag: AnalysisTag

    /// The Mantel test of the transformed matrices.
    let mantel: MantelAnalysis

    /// Creates the analysis.
    ///
    /// - Parameters:
    ///   - differentiation: Pairwise `F` (Φ_ST or θ) among strata.
    ///   - separation: Pairwise separation among the same strata, in any order.
    ///   - logSeparation: Use `ln(separation)`, as for a two-dimensional
    ///     habitat (default `false`).
    ///   - differentiationLabel: The differentiation measure's name (default `"Φ_ST"`).
    ///   - separationLabel: The separation's name (default `"Distance"`).
    ///   - method: The Mantel correlation coefficient (default `.pearson`).
    ///   - tag: The outcome's label (default `AnalysisType.isolationByDistance.tag`).
    /// - Returns: `nil` if the matrices do not name the same strata, a
    ///   separation is not positive when `logSeparation` is set, or fewer than
    ///   three pairs have `F < 1`.
    public init?(differentiation: any PairwiseMatrix,
                 separation: any PairwiseMatrix,
                 logSeparation: Bool = false,
                 differentiationLabel: String = "Φ_ST",
                 separationLabel: String = "Distance",
                 method: CorrelationMethod = .pearson,
                 tag: AnalysisTag = AnalysisType.isolationByDistance.tag) {
        let names = differentiation.groupNames
        guard Set(names) == Set(separation.groupNames), Set(names).count == names.count else { return nil }
        let index = Dictionary(uniqueKeysWithValues: separation.groupNames.enumerated().map { ($1, $0) })
        let order = names.map { index[$0]! }
        let n = names.count

        let linearized = (0..<n).map { i in
            (0..<n).map { j -> Double in
                guard i != j else { return 0 }
                let f = differentiation[i, j]
                return f < 1 ? f / (1 - f) : .infinity
            }
        }
        let separated = (0..<n).map { i in
            (0..<n).map { j -> Double in
                guard i != j else { return 0 }
                let d = separation[order[i], order[j]]
                return logSeparation ? (d > 0 ? Foundation.log(d) : .nan) : d
            }
        }
        guard var mantel = MantelAnalysis(response: linearized, predictor: separated, names: names,
                                          method: method, tag: tag) else { return nil }
        mantel.responseLabel = "\(differentiationLabel) / (1 − \(differentiationLabel))"
        mantel.predictorLabel = (logSeparation ? "the natural log of " : "")
            + AnalysisReport.sentenceCase(separationLabel)
        mantel.unitLabel = "populations"
        self.mantel = mantel
        self.logSeparation = logSeparation
        self.differentiationLabel = differentiationLabel
        self.separationLabel = separationLabel
        self.tag = tag
    }

    /// Runs the Mantel test.
    ///
    /// - Parameter options: Permutation count and seed (R's `set.seed()` value).
    /// - Returns: The outcome; never `nil`.
    public func run(options: AnalysisOptions) -> IsolationByDistanceOutcome? {
        run(options: options) { _, _ in true }
    }

    /// Runs the Mantel test, reporting each permuted correlation as it is drawn.
    ///
    /// - Parameters:
    ///   - options: Permutation count and seed (R's `set.seed()` value).
    ///   - observing: Called after each permutation with the number done and the permuted correlation; return
    ///     `false` to stop.
    /// - Returns: The outcome; a test that `observing` stopped is finished with the permutations it drew.
    public func run(options: AnalysisOptions,
                    observing: (_ done: Int, _ value: Double) -> Bool) -> IsolationByDistanceOutcome? {
        mantel.run(options: options, observing: observing).map {
            IsolationByDistanceOutcome(mantel: $0, logSeparation: logSeparation,
                                       differentiationLabel: differentiationLabel,
                                       separationLabel: separationLabel)
        }
    }
}
