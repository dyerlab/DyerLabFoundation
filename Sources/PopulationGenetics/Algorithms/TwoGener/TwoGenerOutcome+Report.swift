//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  TwoGenerOutcome+Report.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension TwoGenerOutcome {

    /// The AMOVA's values plus `effectivePollenDonors`.
    public var resultsValues: [String: String] {
        var values = amova.resultsValues
        values["effectivePollenDonors"] = effectivePollenDonors.map(AnalysisReport.number) ?? "NA"
        return values
    }
}
