//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AnalysisOutcome.swift
//  Matrix
//
//  What every analysis result reports, so display, logging and persistence
//  code can treat outcomes alike and downcast only for technique-specific
//  detail. `distribution` covers both a permutation null and a set of
//  resampled estimates (rarefaction), as `NullDistributionResult` does; only
//  hypothesis tests turn it into a p-value, so `pValue` is a requirement an
//  outcome can override with `nil`.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// The result of running an ``Analysis``.
public protocol AnalysisOutcome: Sendable {

    /// The technique that produced this outcome.
    var analysisType: AnalysisType { get }

    /// The label this outcome was produced under.
    var tag: AnalysisTag { get }

    /// The primary estimate: Mantel `r`, AMOVA's variance ratio, the mean
    /// rarefied diversity, the posterior mean outcrossing rate, and so on.
    var statistic: Double { get }

    /// The comparison distribution — a permutation null or resampled
    /// estimates — or `nil` if the technique has none or it was skipped.
    var distribution: NullDistributionResult? { get }

    /// An interval around `statistic` (a credible or resampling interval), or
    /// `nil` if the technique gives none.
    var interval: ClosedRange<Double>? { get }

    /// Which tail of `distribution` counts as extreme for `pValue`.
    var testDirection: NullDistributionResult.ComparisonDirection { get }

    /// The p-value of the observed statistic against `distribution`, or `nil`
    /// if the outcome is not a hypothesis test or the test was skipped.
    var pValue: Double? { get }

    /// The values for the Results placeholders, drawn from the estimates.
    var resultsValues: [String: String] { get }

    /// Decisions made while estimating (e.g. a chain that did not converge).
    /// Defaults to none.
    var notes: [AnalysisNote] { get }
}

extension AnalysisOutcome {

    /// No distribution by default.
    public var distribution: NullDistributionResult? { nil }

    /// No interval by default.
    public var interval: ClosedRange<Double>? { nil }

    /// One-sided upper tail, the convention for Mantel and AMOVA.
    public var testDirection: NullDistributionResult.ComparisonDirection { .greaterOrEqual }

    /// The p-value of `distribution` in `testDirection`, or `nil` without one.
    public var pValue: Double? {
        distribution?.pValue(direction: testDirection)
    }

    /// No notes by default.
    public var notes: [AnalysisNote] { [] }
}
