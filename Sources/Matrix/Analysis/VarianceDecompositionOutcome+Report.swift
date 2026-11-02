//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  VarianceDecompositionOutcome+Report.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

extension VarianceDecompositionOutcome {

    /// The variance ratio, its components, degrees of freedom and sums of squares.
    public var resultsValues: [String: String] {
        let d = decomposition
        return [
            "statisticLabel": statisticLabel,
            "ratio": AnalysisReport.number(d.varianceRatio),
            "percentAmong": AnalysisReport.number(100 * d.varianceRatio),
            "sigmaAmong": AnalysisReport.number(d.sigmaAmong),
            "sigmaWithin": AnalysisReport.number(d.sigmaWithin),
            "dfAmong": AnalysisReport.count(d.dfAmong),
            "dfWithin": AnalysisReport.count(d.dfWithin),
            "ssAmong": AnalysisReport.number(d.amongSS),
            "ssWithin": AnalysisReport.number(d.withinSS),
        ]
    }
}
