//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IsolationByDistanceAnalysis+Report.swift
//  PopulationGenetics
//
//  Methods keys: those of `MantelAnalysis` plus `differentiation`,
//  `separation` and `scale`. Results keys: those of `MantelOutcome`.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension IsolationByDistanceAnalysis {

    /// Rousset (1997) isolation by distance wording.
    public static var reportTemplate: AnalysisReportTemplate {
        AnalysisReportTemplate(
            methods: "Isolation by distance was examined following Rousset (1997): pairwise {differentiation} "
                + "among {unitCount} populations was linearized as {response} and compared with {separation}"
                + "{scale}, using a Mantel test (Mantel 1967) and the {method} correlation over {pairCount} pairs. "
                + "{permutations}",
            results: "Genetic differentiation, {response}, was {direction} associated with {separation} "
                + "(Mantel r = {r}, {pValue}; regression slope = {slope}, intercept = {intercept}).")
    }

    /// The Mantel test's values, the differentiation statistic and the scale.
    ///
    /// - Parameter options: The options the analysis runs with.
    /// - Returns: The Methods values.
    public func methodsValues(options: AnalysisOptions) -> [String: String] {
        var values = mantel.methodsValues(options: options)
        values["differentiation"] = differentiationLabel
        values["separation"] = mantel.predictorLabel
        values["scale"] = logSeparation ? " (the scale expected for a two-dimensional habitat)" : ""
        return values
    }

    /// Pairs left out because their differentiation is 1 or more.
    public var notes: [AnalysisNote] {
        let n = mantel.names.count
        let excluded = n * (n - 1) / 2 - mantel.pairCount
        guard excluded > 0 else { return [] }
        return [AnalysisNote(.warning, "\(excluded) population pairs with \(differentiationLabel) ≥ 1 have no "
                             + "finite linearization and were left out of the test.")]
    }
}
