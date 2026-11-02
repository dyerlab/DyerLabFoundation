//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  CorrelatedPaternity+Report.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension CorrelatedPaternity {

    /// `rp`, `pairCount` and `donors` (a clause on the effective number of
    /// pollen donors, 1 / r_p).
    public var resultsValues: [String: String] {
        [
            "rp": AnalysisReport.number(rp),
            "pairCount": AnalysisReport.count(informativePairCount),
            "donors": effectiveNumberOfPollenDonors.map {
                "equivalent to \(AnalysisReport.number($0)) effective pollen donors (1 / r_p)"
            } ?? "giving no evidence of correlated paternity",
        ]
    }
}
