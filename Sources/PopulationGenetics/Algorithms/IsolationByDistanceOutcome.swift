//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IsolationByDistanceOutcome.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// The outcome of an ``IsolationByDistanceAnalysis``.
public struct IsolationByDistanceOutcome: AnalysisOutcome, PairwiseScatterRepresentable {

    /// The Mantel test of linearized differentiation on separation.
    public let mantel: MantelOutcome

    /// Whether separation was log-transformed.
    public let logSeparation: Bool

    /// The differentiation measure's name, e.g. `"Φ_ST"` or `"θ"`.
    public let differentiationLabel: String

    /// The separation's name, e.g. `"Distance (km)"`.
    public let separationLabel: String

    /// Always `AnalysisType.isolationByDistance`.
    public var analysisType: AnalysisType { .isolationByDistance }

    /// The label this outcome was produced under.
    public var tag: AnalysisTag { mantel.tag }

    /// The Mantel correlation between linearized differentiation and separation.
    public var statistic: Double { mantel.r }

    /// The Mantel permutation null, or `nil` if not tested.
    public var distribution: NullDistributionResult? { mantel.distribution }

    /// The least-squares slope of `F / (1 − F)` on (log) separation. In a
    /// two-dimensional habitat with log separation this estimates
    /// `1 / (4 D σ²)` (Rousset 1997).
    public var slope: Double? { mantel.line?.slope }

    /// Population pairs as linearized differentiation against separation, with
    /// the fitted line.
    public var scatter: PairwiseScatter {
        mantel.scatter(xLabel: logSeparation ? "ln(\(separationLabel))" : separationLabel,
                       yLabel: "\(differentiationLabel) / (1 − \(differentiationLabel))")
    }
}
