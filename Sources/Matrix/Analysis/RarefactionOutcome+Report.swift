//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RarefactionOutcome+Report.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

extension RarefactionOutcome {

    /// The rarefied mean and interval, the full-sample value and the size.
    public var resultsValues: [String: String] {
        [
            "mean": AnalysisReport.number(statistic),
            "fullSample": AnalysisReport.number(fullSampleValue),
            "size": AnalysisReport.count(size),
        ]
    }
}
