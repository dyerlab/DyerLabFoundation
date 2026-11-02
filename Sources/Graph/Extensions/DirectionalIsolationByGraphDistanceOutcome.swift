//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DirectionalIsolationByGraphDistanceOutcome.swift
//  Graph
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// The outcome of a ``DirectionalIsolationByGraphDistanceAnalysis``.
public struct DirectionalIsolationByGraphDistanceOutcome: AnalysisOutcome, PairwiseScatterRepresentable {

    /// The fit summary: `ΔR²`, both `R²`s, and the forward and reverse slopes.
    public let result: DirectionalIsolationByGraphDistanceResult

    /// The fitted model's intercept, shared by both directions.
    public let intercept: Double

    /// Ordered pairs `(i, j)` running in the hypothesized forward direction,
    /// as separation (`x`) against pGD from `i` to `j` (`y`).
    public let forwardPoints: [PairwisePoint]

    /// Ordered pairs running in the reverse direction.
    public let reversePoints: [PairwisePoint]

    /// The separation's name, e.g. `"River distance (km)"`.
    public let separationLabel: String

    /// The label this outcome was produced under.
    public let tag: AnalysisTag

    /// Always `AnalysisType.directionalIsolationByGraphDistance`.
    public var analysisType: AnalysisType { .directionalIsolationByGraphDistance }

    /// `ΔR² = adjusted R²_pGD − R²_cGD`; positive favours the directional model.
    public var statistic: Double { result.deltaR2 }

    /// Forward and reverse pairs, each with its own fitted line.
    public var scatter: PairwiseScatter {
        PairwiseScatter(xLabel: separationLabel, yLabel: "pGD", series: [
            PairwiseSeries(name: "Forward", points: forwardPoints,
                           line: RegressionLine(intercept: intercept, slope: result.forwardSlope)),
            PairwiseSeries(name: "Reverse", points: reversePoints,
                           line: RegressionLine(intercept: intercept, slope: result.reverseSlope)),
        ])
    }
}
