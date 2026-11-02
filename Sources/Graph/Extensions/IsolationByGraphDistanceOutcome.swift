//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IsolationByGraphDistanceOutcome.swift
//  Graph
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// The outcome of an ``IsolationByGraphDistanceAnalysis``.
public struct IsolationByGraphDistanceOutcome: AnalysisOutcome, PairwiseScatterRepresentable {

    /// The Mantel test of cGD on separation, over connected population pairs.
    public let mantel: MantelOutcome

    /// The separation's name, e.g. `"Distance (km)"`.
    public let separationLabel: String

    /// Always `AnalysisType.isolationByGraphDistance`.
    public var analysisType: AnalysisType { .isolationByGraphDistance }

    /// The label this outcome was produced under.
    public var tag: AnalysisTag { mantel.tag }

    /// Pearson `r` between cGD and separation.
    public var statistic: Double { mantel.r }

    /// The Mantel permutation null, or `nil` if not tested.
    public var distribution: NullDistributionResult? { mantel.distribution }

    /// Connected population pairs as cGD against separation, with the fitted line.
    public var scatter: PairwiseScatter {
        mantel.scatter(xLabel: separationLabel, yLabel: "cGD")
    }
}
