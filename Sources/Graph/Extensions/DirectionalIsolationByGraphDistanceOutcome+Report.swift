//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DirectionalIsolationByGraphDistanceOutcome+Report.swift
//  Graph
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension DirectionalIsolationByGraphDistanceOutcome {

    /// The fit statistics and slopes.
    public var resultsValues: [String: String] {
        [
            "pairCount": AnalysisReport.count(result.pairs),
            "deltaR2": AnalysisReport.number(result.deltaR2),
            "moreOrLess": result.deltaR2 >= 0 ? "more" : "less",
            "r2CGD": AnalysisReport.number(result.r2CGD),
            "adjustedR2PGD": AnalysisReport.number(result.adjustedR2PGD),
            "forwardSlope": AnalysisReport.number(result.forwardSlope),
            "reverseSlope": AnalysisReport.number(result.reverseSlope),
            "slopeRatio": AnalysisReport.number(result.slopeRatio),
            "intercept": AnalysisReport.number(intercept),
        ]
    }
}
