//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  VarianceDecompositionAnalysis.swift
//  Matrix
//
//  `DistanceVarianceDecomposition` as an `Analysis`. The technique is the
//  same whatever the distances are, so AMOVA (Φ_ST), a single-locus θ and
//  2Gener's pollen-pool Φ_FT are all this analysis with a different distance
//  matrix and `tag`.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// A distance-based variance decomposition (``AnalysisType/amova``) bound to
/// its distances and partition.
public struct VarianceDecompositionAnalysis: Analysis {

    /// ``AnalysisType/amova``.
    public static let analysisType: AnalysisType = .amova

    /// The label for the outcome.
    public let tag: AnalysisTag

    /// The group index of each unit, in distance-matrix order.
    public let partition: [Int]

    /// The statistic's symbol, for the report (e.g. "Φ_ST", "θ", "Φ_FT").
    public var statisticLabel = "Φ"

    /// What the units are, plural, for the report (e.g. "individuals").
    public var unitLabel = "units"

    /// What the groups are, plural, for the report (e.g. "populations").
    public var groupLabel = "groups"

    /// The decomposition engine, holding the squared distances.
    private let decomposition: DistanceVarianceDecomposition

    /// Creates the analysis.
    ///
    /// - Parameters:
    ///   - squaredDistances: An `n × n` symmetric matrix of squared distances.
    ///   - partition: A group label per unit (`n` labels); any integers will do.
    ///   - tag: The outcome's label (default `AnalysisType.amova.tag`).
    /// - Returns: `nil` if the matrix is not square, `partition` is the wrong
    ///   length, or there are fewer than two groups or no within-group
    ///   degrees of freedom.
    public init?(squaredDistances: [[Double]], partition: [Int], tag: AnalysisTag = AnalysisType.amova.tag) {
        let n = squaredDistances.count
        let groups = Set(partition).count
        guard squaredDistances.allSatisfy({ $0.count == n }),
              partition.count == n,
              groups >= 2,
              n > groups else { return nil }

        self.partition = partition
        self.tag = tag
        self.decomposition = DistanceVarianceDecomposition(squaredDistances: squaredDistances)
    }

    /// Decomposes the variance and, if `options.iterations > 0`, tests the
    /// variance ratio by permuting group membership.
    ///
    /// - Parameter options: Permutation count and seed.
    /// - Returns: The decomposition and its null distribution; never `nil`.
    public func run(options: AnalysisOptions) -> VarianceDecompositionOutcome? {
        run(options: options) { _ in true }
    }

    /// Decomposes the variance and, if `options.iterations > 0`, tests the variance ratio by permuting group
    /// membership, reporting each permutation as it finishes.
    ///
    /// The permutations are the same as ``run(options:)``'s, so a seed reproduces the same p-value.
    ///
    /// - Parameters:
    ///   - options: Permutation count and seed.
    ///   - progress: Called after each permutation with the number done; return `false` to stop.
    /// - Returns: The decomposition and its null distribution (of fewer values if `progress` stopped the test).
    public func run(options: AnalysisOptions, progress: (Int) -> Bool) -> VarianceDecompositionOutcome? {
        run(options: options, observing: { done, _ in progress(done) })
    }

    /// Decomposes the variance and, if `options.iterations > 0`, tests the variance ratio, handing over each
    /// permuted ratio as it is drawn.
    ///
    /// - Parameters:
    ///   - options: Permutation count and seed.
    ///   - observing: Called after each permutation with the number done and its ratio; return `false` to stop,
    ///     which finishes the test with the permutations drawn so far.
    /// - Returns: The decomposition and its null distribution (of fewer values if `observing` stopped the test).
    public func run(options: AnalysisOptions,
                    observing: (_ done: Int, _ value: Double) -> Bool) -> VarianceDecompositionOutcome? {
        var null: NullDistributionResult?
        if options.iterations > 0 {
            null = Resampling.permutationTest(labels: partition, iterations: options.iterations, seed: options.seed,
                                              tag: tag, observing: observing) { labels in
                decomposition.decompose(partition: labels).varianceRatio
            }
        }
        return VarianceDecompositionOutcome(tag: tag, statisticLabel: statisticLabel,
                                            decomposition: decomposition.decompose(partition: partition),
                                            distribution: null)
    }
}
