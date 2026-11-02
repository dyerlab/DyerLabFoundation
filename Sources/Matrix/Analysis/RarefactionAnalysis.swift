//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RarefactionAnalysis.swift
//  Matrix
//
//  Rarefaction in general: any statistic of a sample, re-estimated over
//  repeated subsamples of a smaller size so samples of different sizes can be
//  compared. Domain modules supply the statistic (e.g. PopulationGenetics'
//  diversity measures); the technique is the same.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// Rarefaction of a statistic over subsamples of a fixed size
/// (``AnalysisType/rarefaction``).
public struct RarefactionAnalysis<Unit: Sendable>: Analysis {

    /// ``AnalysisType/rarefaction``.
    public static var analysisType: AnalysisType { .rarefaction }

    /// The full sample.
    public let population: [Unit]

    /// The subsample size.
    public let size: Int

    /// The label for the outcome.
    public let tag: AnalysisTag

    /// The statistic's name, for the report (e.g. "allelic richness").
    public var statisticLabel = "the statistic"

    /// What the units are, plural, for the report (e.g. "individuals").
    public var unitLabel = "units"

    /// The statistic to rarefy, computed on a sample.
    private let statistic: @Sendable ([Unit]) -> Double

    /// Creates the analysis.
    ///
    /// - Parameters:
    ///   - population: The full sample.
    ///   - size: The subsample size, in `1..<population.count`.
    ///   - tag: The outcome's label (default `AnalysisType.rarefaction.tag`).
    ///   - statistic: The statistic to rarefy.
    /// - Returns: `nil` if `size` is not in `1..<population.count`.
    public init?(population: [Unit],
                 size: Int,
                 tag: AnalysisTag = AnalysisType.rarefaction.tag,
                 statistic: @escaping @Sendable ([Unit]) -> Double) {
        guard size > 0, size < population.count else { return nil }
        self.population = population
        self.size = size
        self.tag = tag
        self.statistic = statistic
    }

    /// Draws `options.iterations` subsamples without replacement.
    ///
    /// - Parameter options: Number of subsamples and seed.
    /// - Returns: The rarefied estimates, or `nil` if `options.iterations` is `0`.
    public func run(options: AnalysisOptions) -> RarefactionOutcome? {
        guard options.iterations > 0 else { return nil }
        let resampled = Resampling.subsampleTest(population: population, size: size,
                                                 iterations: options.iterations, seed: options.seed,
                                                 tag: tag, statistic: statistic)
        return RarefactionOutcome(tag: tag, resampled: resampled)
    }
}
