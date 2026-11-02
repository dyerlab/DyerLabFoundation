//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IsolationByGraphDistanceAnalysis+Report.swift
//  Graph
//
//  Methods keys: those of `MantelAnalysis` (`separation` is the predictor).
//  Results keys: those of `MantelOutcome`.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension IsolationByGraphDistanceAnalysis {

    /// Isolation by graph distance wording.
    public static var reportTemplate: AnalysisReportTemplate {
        AnalysisReportTemplate(
            methods: "Isolation by graph distance was tested by correlating conditional genetic distance "
                + "(cGD; Dyer, Nason & Garrick 2010), the shortest-path distance between populations through the "
                + "population graph (Dyer & Nason 2004), with {separation} among {unitCount} populations "
                + "({pairCount} connected pairs) using a Mantel test (Mantel 1967) and the {method} correlation. "
                + "{permutations}",
            results: "Conditional genetic distance was {direction} associated with {separation} "
                + "(Mantel r = {r}, {pValue}; {pairCount} connected pairs).")
    }

    /// The Mantel test's values, with the separation named.
    ///
    /// - Parameter options: The options the analysis runs with.
    /// - Returns: The Methods values.
    public func methodsValues(options: AnalysisOptions) -> [String: String] {
        var values = mantel.methodsValues(options: options)
        values["separation"] = mantel.predictorLabel
        return values
    }
}
