//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RarefactionOutcome.swift
//  Matrix
//
//  Rarefaction is an estimate, not a hypothesis test: `statistic` is the mean
//  of the rarefied estimates and `interval` their central 95%, and `pValue`
//  is deliberately `nil` even though there is a resampling distribution. The
//  outcome is the same whatever statistic was rarefied.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// The outcome of a rarefaction (``AnalysisType/rarefaction``).
public struct RarefactionOutcome: AnalysisOutcome {

    /// The label this outcome was produced under.
    public let tag: AnalysisTag

    /// The full-sample value (`observed`) and the rarefied estimates (`values`).
    public let resampled: NullDistributionResult

    /// Creates an outcome.
    ///
    /// - Parameters:
    ///   - tag: The label this outcome was produced under.
    ///   - resampled: The full-sample value and the rarefied estimates.
    public init(tag: AnalysisTag, resampled: NullDistributionResult) {
        self.tag = tag
        self.resampled = resampled
    }

    /// Always ``AnalysisType/rarefaction``.
    public var analysisType: AnalysisType { .rarefaction }

    /// The subsample size.
    public var size: Int { resampled.size ?? 0 }

    /// The statistic computed on the full sample.
    public var fullSampleValue: Double { resampled.observed }

    /// The mean of the rarefied estimates, or `.nan` if there are none.
    public var statistic: Double {
        resampled.values.isEmpty ? .nan : resampled.values.reduce(0, +) / Double(resampled.values.count)
    }

    /// The rarefied estimates.
    public var distribution: NullDistributionResult? { resampled }

    /// The central 95% of the rarefied estimates (R's type-7 quantiles), or
    /// `nil` if there are none.
    public var interval: ClosedRange<Double>? {
        guard !resampled.values.isEmpty else { return nil }
        return empiricalQuantile(resampled.values, probability: 0.025)
            ... empiricalQuantile(resampled.values, probability: 0.975)
    }

    /// Always `nil`: rarefaction is an estimate, not a test.
    public var pValue: Double? { nil }
}
