//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  VarianceDecompositionAnalysis+Report.swift
//  Matrix
//
//  Methods keys: `statisticLabel`, `units`, `groups`, `unitCount`,
//  `groupCount`, `permutations`. Results keys (from
//  `VarianceDecompositionOutcome`): `ratio`, `percentAmong`, `sigmaAmong`,
//  `sigmaWithin`, `dfAmong`, `dfWithin`, `ssAmong`, `ssWithin`.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

extension VarianceDecompositionAnalysis {

    /// AMOVA (Excoffier, Smouse & Quattro 1992) wording.
    public static var reportTemplate: AnalysisReportTemplate {
        AnalysisReportTemplate(
            methods: "Variation among {unitCount} {units} was partitioned among and within {groupCount} {groups} "
                + "with an analysis of molecular variance (AMOVA; Excoffier, Smouse & Quattro 1992), "
                + "summarized as {statisticLabel}. {permutations}",
            results: "{percentAmong}% of the variation was among {groups} "
                + "({statisticLabel} = {ratio}, {pValue}; σ²_among = {sigmaAmong}, σ²_within = {sigmaWithin}, "
                + "df = {dfAmong}, {dfWithin}).")
    }

    /// The labels, sizes and permutation design.
    ///
    /// - Parameter options: The options the analysis runs with.
    /// - Returns: The Methods values.
    public func methodsValues(options: AnalysisOptions) -> [String: String] {
        [
            "statisticLabel": statisticLabel,
            "units": unitLabel,
            "groups": groupLabel,
            "unitCount": AnalysisReport.count(partition.count),
            "groupCount": AnalysisReport.count(Set(partition).count),
            "permutations": AnalysisReport.permutationSentence(options, permuting: "\(unitLabel) among \(groupLabel)"),
        ]
    }
}
