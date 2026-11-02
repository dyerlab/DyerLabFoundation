//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  OutcrossingResult+Report.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension Outcrossing.Result {

    /// The posterior means of t and F and the number of retained samples.
    public var resultsValues: [String: String] {
        [
            "t": AnalysisReport.number(meanT),
            "F": AnalysisReport.number(meanF),
            "sampleCount": AnalysisReport.count(samples.count),
        ]
    }
}
