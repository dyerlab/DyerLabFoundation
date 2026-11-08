//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  WeirCockerhamOutcome.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// The outcome of a ``WeirCockerhamAnalysis``: θ, F_IS and F_IT at one locus, and θ's permutation test.
public struct WeirCockerhamOutcome: AnalysisOutcome {

    /// The label the analysis ran under.
    public let tag: AnalysisTag

    /// The locus's name.
    public let locus: String

    /// The variance components and the analysis of variance behind them.
    public let decomposition: WeirCockerhamDecomposition

    /// θ's permutation null distribution, or `nil` if it wasn't tested.
    public let distribution: NullDistributionResult?

    /// `AnalysisType.weirCockerham`.
    public var analysisType: AnalysisType { .weirCockerham }

    /// θ.
    public var statistic: Double { decomposition.theta }

    /// The F-statistics and variance components.
    public var resultsValues: [String: String] {
        let d = decomposition
        return [
            "theta": AnalysisReport.number(d.theta),
            "fIS": AnalysisReport.number(d.fIS),
            "fIT": AnalysisReport.number(d.fIT),
            "sigmaAmong": AnalysisReport.number(d.sigmaAmong),
            "sigmaIndividuals": AnalysisReport.number(d.sigmaIndividuals),
            "sigmaWithin": AnalysisReport.number(d.sigmaWithin),
        ]
    }
}
