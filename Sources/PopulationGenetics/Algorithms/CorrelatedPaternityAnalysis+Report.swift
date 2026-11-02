//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  CorrelatedPaternityAnalysis+Report.swift
//  PopulationGenetics
//
//  Methods keys: `offspringCount`, `familyCount`, `locusCount`. Results keys
//  (from `CorrelatedPaternity`): `rp`, `pairCount`, `donors`.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension CorrelatedPaternityAnalysis {

    /// Ritland (1989) correlated paternity wording.
    public static var reportTemplate: AnalysisReportTemplate {
        AnalysisReportTemplate(
            methods: "Correlated paternity (r_p), the probability that two outcrossed siblings share a father, "
                + "was estimated with Ritland's (1989) moment estimator from the paternal alleles of sibling pairs "
                + "in {familyCount} maternal families ({offspringCount} offspring) at {locusCount} loci, against "
                + "the background match probability implied by the pollen-pool allele frequencies.",
            results: "Correlated paternity was r_p = {rp} ({pairCount} informative sib-pair loci), "
                + "{donors}.")
    }

    /// The sample.
    ///
    /// - Parameter options: Unused; the estimator has no resampling.
    /// - Returns: The Methods values.
    public func methodsValues(options: AnalysisOptions) -> [String: String] {
        [
            "offspringCount": AnalysisReport.count(design.offspringOrdinals.count),
            "familyCount": AnalysisReport.count(design.families.count),
            "locusCount": AnalysisReport.count(matrix.locusCount),
        ]
    }
}
