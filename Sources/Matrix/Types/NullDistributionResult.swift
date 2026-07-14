//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  NullDistributionResult.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 7/13/26.
//
//  The shared shape behind every "observed value vs. a distribution of
//  comparison values" analysis: a permutation test (observed vs.
//  label-shuffled nulls) and rarefaction (observed vs. estimates from
//  repeated resampling at a reduced size) are mechanically the same
//  computation — resample, recompute, collect, then ask where the observed
//  value sits in that distribution.
//

/// An observed statistic together with a distribution of comparison values
/// (permuted nulls, or resampled estimates) to judge it against.
///
/// This is an in-memory computation result, not a persisted record — it is
/// deliberately not `Codable`. A caller that wants a durable artifact
/// renders `values` into a density-plot image and writes the observed value
/// and `pValue(direction:)` as text into its own analysis-record type; the
/// raw comparison values don't need to survive past that rendering step.
public struct NullDistributionResult: Sendable, Equatable {

    /// Which analysis produced this result.
    public var analysisType: AnalysisTag

    /// The observed statistic from the actual (unpermuted / full-size) data.
    public var observed: Double

    /// The comparison distribution: permuted nulls, or resampled estimates.
    public var values: [Double]

    /// The subsample size used, for a resampling-based analysis. `nil` for
    /// a permutation test over the full dataset, which has no subsample size.
    public var size: Int?

    /// The PRNG seed used, if resampling was seeded for reproducibility.
    /// `nil` if unseeded.
    public var seed: UInt64?

    /// Creates a result.
    ///
    /// - Parameters:
    ///   - analysisType: Which analysis produced this result.
    ///   - observed: The observed statistic from the actual data.
    ///   - values: The comparison distribution.
    ///   - size: The subsample size used, for resampling (defaults to `nil`).
    ///   - seed: The PRNG seed used, if seeded (defaults to `nil`).
    public init(analysisType: AnalysisTag, observed: Double, values: [Double],
                size: Int? = nil, seed: UInt64? = nil) {
        self.analysisType = analysisType
        self.observed = observed
        self.values = values
        self.size = size
        self.seed = seed
    }
}

extension NullDistributionResult {

    /// Which tail(s) of `values` count as "as extreme as `observed`".
    public enum ComparisonDirection: Sendable {
        /// One-sided: values at least as large as `observed`. The
        /// conventional direction for "is the observed statistic unusually
        /// large" permutation tests.
        case greaterOrEqual
        /// One-sided: values at least as small as `observed`.
        case lessOrEqual
        /// Two-sided: twice the smaller one-sided tail, capped at `1.0`.
        case notEqualTo
    }

    /// - Precondition: `values` is non-empty (`pValue(direction:)` guards this before calling).
    private func tailProportion(_ isExtreme: (Double) -> Bool) -> Double {
        Double(values.filter(isExtreme).count + 1) / Double(values.count + 1)
    }

    /// The proportion of `values` at least as extreme as `observed`, in the
    /// given direction (Davison–Hinkley `+1` correction).
    ///
    /// For a permutation test this is the classic p-value. For rarefaction
    /// it's the same computation read as "where does the full-sample
    /// estimate fall relative to the distribution of resampled estimates" —
    /// the same mechanics serve both interpretations, computed on demand
    /// (never stored) so it can't drift out of sync with `values` and so the
    /// caller picks the direction that matches their actual question.
    public func pValue(direction: ComparisonDirection = .greaterOrEqual) -> Double {
        // Checked once up front rather than left to propagate through the
        // arithmetic below: `min(1.0, .nan)` returns `1.0`, not `.nan` — the
        // stdlib's `min`/`max` fall through to their first argument whenever
        // a NaN comparison is involved, so the `.notEqualTo` branch would
        // otherwise silently report a p-value of `1.0` for empty `values`
        // instead of the correct "undefined" `.nan`.
        guard !values.isEmpty else { return .nan }
        switch direction {
        case .greaterOrEqual: return tailProportion { $0 >= observed }
        case .lessOrEqual: return tailProportion { $0 <= observed }
        case .notEqualTo:
            let upper = tailProportion { $0 >= observed }
            let lower = tailProportion { $0 <= observed }
            return min(1.0, 2.0 * min(upper, lower))
        }
    }
}
