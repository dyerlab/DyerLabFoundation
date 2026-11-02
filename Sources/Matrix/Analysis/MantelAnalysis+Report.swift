//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MantelAnalysis+Report.swift
//  Matrix
//
//  Methods keys: `response` (and `Response`, capitalized), `predictor`, `units`, `unitCount`, `pairCount`,
//  `method`, `permutations` (a sentence). Results keys (from
//  `MantelOutcome`): `r`, `direction`, `slope`, `intercept`.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

extension MantelAnalysis {

    /// Mantel (1967) test wording.
    public static var reportTemplate: AnalysisReportTemplate {
        AnalysisReportTemplate(
            methods: "The association between {response} and {predictor} among {unitCount} {units} "
                + "({pairCount} pairs) was estimated with a Mantel test (Mantel 1967) using the {method} "
                + "correlation. {permutations}",
            results: "{Response} was {direction} associated with {predictor} "
                + "(Mantel r = {r}, {pValue}; {pairCount} pairs).")
    }

    /// The data's labels and sizes and the permutation design.
    ///
    /// - Parameter options: The options the analysis runs with.
    /// - Returns: The Methods values.
    public func methodsValues(options: AnalysisOptions) -> [String: String] {
        [
            "response": responseLabel,
            "Response": responseLabel.prefix(1).uppercased() + responseLabel.dropFirst(),
            "predictor": predictorLabel,
            "units": unitLabel,
            "unitCount": AnalysisReport.count(names.count),
            "pairCount": AnalysisReport.count(pairCount),
            "method": method.displayName,
            "permutations": AnalysisReport.permutationSentence(
                options, permuting: "the rows and columns of the \(predictorLabel) matrix"),
        ]
    }
}
