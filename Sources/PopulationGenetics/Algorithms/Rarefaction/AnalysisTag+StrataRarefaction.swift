//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AnalysisTag+StrataRarefaction.swift
//  PopulationGenetics
//
//  The tag for diversity rarefied among strata.
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension AnalysisTag {

    /// Diversity statistics rarefied among strata to a common sample size (`StrataRarefactionAnalysis`).
    public static let strataRarefaction = AnalysisTag("strataRarefaction")
}
