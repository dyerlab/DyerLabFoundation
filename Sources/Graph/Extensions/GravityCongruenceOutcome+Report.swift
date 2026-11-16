//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GravityCongruenceOutcome+Report.swift
//  Graph
//
//  Results keys: `rho`, `rhoAgreement`, `pValue`, `concordantEdges`,
//  `directedEdges`, `edgeConcordance` and `edgePValue`.
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension GravityCongruenceOutcome {

    /// The correlation, the edge concordance and their P values.
    public var resultsValues: [String: String] {
        [
            "rho": AnalysisReport.number(rho),
            "rhoAgreement": (pValue ?? 1) < 0.05 ? "correlated" : "not significantly correlated",
            "pValue": pValue.map { AnalysisReport.pValue($0) } ?? "untested",
            "concordantEdges": AnalysisReport.count(concordantEdges),
            "directedEdges": AnalysisReport.count(directedEdges),
            "edgeConcordance": edgeConcordance.map { AnalysisReport.number($0) } ?? "NA",
            "edgePValue": AnalysisReport.pValue(edgePValue),
        ]
    }
}
