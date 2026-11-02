//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MantelOutcome.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// The outcome of a ``MantelAnalysis``.
public struct MantelOutcome: AnalysisOutcome {

    /// The label this outcome was produced under.
    public let tag: AnalysisTag

    /// The correlation coefficient used.
    public let method: CorrelationMethod

    /// The Mantel statistic: the correlation between the two matrices over
    /// the pairs used.
    public let r: Double

    /// The unit pairs the correlation was computed over: predictor as `x`,
    /// response as `y`.
    public let points: [PairwisePoint]

    /// The least-squares line of response on predictor, or `nil` if the
    /// predictor is constant over the pairs.
    public let line: RegressionLine?

    /// The permutation null of `r`, or `nil` if not tested.
    public let distribution: NullDistributionResult?

    /// Always ``AnalysisType/mantel``.
    public var analysisType: AnalysisType { .mantel }

    /// The Mantel statistic, ``r``.
    public var statistic: Double { r }

    /// The number of unit pairs the correlation was computed over.
    public var pairCount: Int { points.count }

    /// The pairs as a one-series scatter with the fitted line.
    ///
    /// - Parameters:
    ///   - xLabel: The predictor axis label.
    ///   - yLabel: The response axis label.
    ///   - seriesName: The series' legend name (default `"Pairs"`).
    /// - Returns: The scatter.
    public func scatter(xLabel: String, yLabel: String, seriesName: String = "Pairs") -> PairwiseScatter {
        PairwiseScatter(xLabel: xLabel, yLabel: yLabel,
                        series: [PairwiseSeries(name: seriesName, points: points, line: line)])
    }
}
