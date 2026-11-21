//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DirectionalIsolationByGraphDistanceAnalysis+Report.swift
//  Graph
//
//  Methods keys: `separation`, `gamma`, `unitCount`. Results keys (from
//  `DirectionalIsolationByGraphDistanceOutcome`): `pairCount`, `deltaR2`, `moreOrLess`,
//  `r2CGD`, `adjustedR2DCGD`, `forwardSlope`, `reverseSlope`, `slopeRatio`,
//  `intercept`.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension DirectionalIsolationByGraphDistanceAnalysis {

    /// Directional isolation by graph distance wording.
    ///
    /// "Dyer, in review" is Dyer RJ, Genetic Gravity: Extracting Directional Gene Flow from Population Graphs,
    /// *Molecular Ecology* (in review), which defines dcGD.
    public static var reportTemplate: AnalysisReportTemplate {
        AnalysisReportTemplate(
            methods: "Directional isolation by graph distance among {unitCount} populations was assessed by "
                + "regressing directional conditional genetic distance (dcGD, γ = {gamma}; Dyer, in review) on "
                + "{separation}, with separate slopes for pairs in the hypothesized forward and reverse "
                + "directions ({pairCount} ordered pairs). Its adjusted R² was compared with the R² of conditional "
                + "genetic distance (cGD; Dyer, Nason & Garrick 2010) on {separation}. No significance test was "
                + "performed.",
            results: "dcGD explained {moreOrLess} of the variation than cGD (ΔR² = {deltaR2}; adjusted R² = "
                + "{adjustedR2DCGD} vs. R² = {r2CGD}; {pairCount} ordered pairs). The forward slope was {forwardSlope} and the reverse slope {reverseSlope} (ratio {slopeRatio}).")
    }

    /// The separation, γ and the number of populations.
    ///
    /// - Parameter options: Unused; the analysis has no resampling.
    /// - Returns: The Methods values.
    public func methodsValues(options: AnalysisOptions) -> [String: String] {
        [
            "separation": AnalysisReport.sentenceCase(separationLabel),
            "gamma": AnalysisReport.number(gamma),
            "unitCount": AnalysisReport.count(placedCount),
        ]
    }
}
