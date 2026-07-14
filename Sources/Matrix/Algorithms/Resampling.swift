//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  Resampling.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 7/14/26.
//
//  Two shared resampling engines behind any "observed value vs. an
//  empirical null/comparison distribution" analysis. Both are closure-based
//  rather than protocol-based: what varies between callers is a single
//  statistic computation over a relabeled/resampled collection, which is
//  naturally a closure, not a type requiring conformance ceremony. Callers
//  own any size-scaling or precondition-guarding their own statistic needs
//  (e.g. sampling twice as many sub-units as a nominal "size") — these
//  engines stay ignorant of that, deliberately, since only the caller knows
//  the relationship between its own units and its statistic.
//

/// Namespace for the two shared resampling engines. A caseless enum rather
/// than top-level functions: `Matrix` is both this package's module name
/// and a type it exports (`Matrices/Matrix.swift`), so an unqualified
/// top-level `permutationTest` would be unreachable-by-qualification from
/// call sites that also define their own same-named method (as
/// `DistanceVarianceDecomposition.permutationTest` does) — there'd be no
/// way to write `Matrix.permutationTest(...)` to disambiguate, since that
/// resolves to the `Matrix` type, not the module. Namespacing under
/// `Resampling` avoids the collision entirely.
public enum Resampling {

    /// A permutation test: repeatedly shuffles `labels` and recomputes
    /// `statistic`, building an empirical null distribution to judge the
    /// observed (unshuffled) value against.
    ///
    /// - Parameters:
    ///   - labels: The observed labeling/partition, unshuffled.
    ///   - iterations: Number of permutations.
    ///   - seed: PRNG seed, for reproducibility.
    ///   - tag: Which analysis this is, for the result's `analysisType`.
    ///   - statistic: Computes the statistic of interest for a given labeling.
    /// - Returns: The observed statistic plus the permuted null distribution.
    public static func permutationTest<Label>(
        labels: [Label],
        iterations: Int,
        seed: UInt64,
        tag: AnalysisTag,
        statistic: ([Label]) -> Double
    ) -> NullDistributionResult {
        let observed = statistic(labels)
        var rng = SplitMix64(seed: seed)
        var shuffled = labels
        var values = [Double]()
        values.reserveCapacity(iterations)
        for _ in 0..<iterations {
            shuffled.shuffle(using: &rng)
            values.append(statistic(shuffled))
        }
        return NullDistributionResult(analysisType: tag, observed: observed, values: values, seed: seed)
    }

    /// A resampling (rarefaction-style) test: repeatedly draws a
    /// `size`-element subsample without replacement from `population` and
    /// recomputes `statistic`, building a distribution of reduced-sample
    /// estimates to judge the observed (full-population) value against.
    ///
    /// - Parameters:
    ///   - population: The full population to resample from.
    ///   - size: The subsample size to draw each iteration. Callers whose
    ///     unit of resampling differs from their unit of measurement (e.g.
    ///     drawing alleles to estimate a genotype-level metric) are
    ///     responsible for scaling this themselves — the engine draws
    ///     exactly `size` elements of `population`, nothing more.
    ///   - iterations: Number of resampling iterations.
    ///   - seed: PRNG seed, for reproducibility.
    ///   - tag: Which analysis this is, for the result's `analysisType`.
    ///   - statistic: Computes the statistic of interest for a given sample.
    /// - Returns: The observed (full-population) statistic plus the
    ///   distribution of resampled estimates.
    public static func subsampleTest<Unit>(
        population: [Unit],
        size: Int,
        iterations: Int,
        seed: UInt64,
        tag: AnalysisTag,
        statistic: ([Unit]) -> Double
    ) -> NullDistributionResult {
        let observed = statistic(population)
        var rng = SplitMix64(seed: seed)
        var values = [Double]()
        values.reserveCapacity(iterations)
        for _ in 0..<iterations {
            let sample = Array(population.shuffled(using: &rng).prefix(size))
            values.append(statistic(sample))
        }
        return NullDistributionResult(analysisType: tag, observed: observed, values: values, size: size, seed: seed)
    }
}
