//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MantelOutcome+Report.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

extension MantelOutcome {

    /// `r`, `direction` ("positively", "negatively" or "not"), `pairCount`,
    /// `slope` and `intercept`.
    public var resultsValues: [String: String] {
        [
            "r": AnalysisReport.number(r),
            "direction": r > 0 ? "positively" : (r < 0 ? "negatively" : "not"),
            "pairCount": AnalysisReport.count(pairCount),
            "slope": line.map { AnalysisReport.number($0.slope) } ?? "NA",
            "intercept": line.map { AnalysisReport.number($0.intercept) } ?? "NA",
        ]
    }
}
