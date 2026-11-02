//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  VarianceDecompositionOutcome.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// The outcome of a ``VarianceDecompositionAnalysis``.
public struct VarianceDecompositionOutcome: AnalysisOutcome {

    /// The label this outcome was produced under.
    public let tag: AnalysisTag

    /// The statistic's symbol, for the report (e.g. "Φ_ST").
    public let statisticLabel: String

    /// The sums of squares, variance components and variance ratio.
    public let decomposition: DistanceVarianceDecompositionResult

    /// The permutation null of the variance ratio, or `nil` if not tested.
    public let distribution: NullDistributionResult?

    /// Always ``AnalysisType/amova``.
    public var analysisType: AnalysisType { .amova }

    /// The among/total variance ratio σ²_A / (σ²_A + σ²_W).
    public var statistic: Double { decomposition.varianceRatio }
}
