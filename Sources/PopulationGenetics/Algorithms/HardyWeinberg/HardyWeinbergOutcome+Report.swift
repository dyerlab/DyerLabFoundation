//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  HardyWeinbergOutcome+Report.swift
//  PopulationGenetics
//
//  Results keys: `locus`, `where`, `statistic`, `df`, `pValue` and
//  `departure` ("departed from" when P < 0.05, else "did not depart from").
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension HardyWeinbergOutcome {

    /// The statistic, its degrees of freedom and P.
    public var resultsValues: [String: String] {
        [
            "locus": locus,
            "where": stratum.map { " in \($0)" } ?? "",
            "statistic": AnalysisReport.number(statistic),
            "df": AnalysisReport.count(degreesOfFreedom),
            "pValue": AnalysisReport.pValue(pValue),
            "departure": (pValue ?? 1) < 0.05 ? "departed from" : "did not depart from",
        ]
    }
}
