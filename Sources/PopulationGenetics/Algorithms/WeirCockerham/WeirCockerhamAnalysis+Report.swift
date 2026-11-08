//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  WeirCockerhamAnalysis+Report.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension WeirCockerhamAnalysis {

    /// Weir & Cockerham (1984) wording.
    public static var reportTemplate: AnalysisReportTemplate {
        AnalysisReportTemplate(
            methods: "Genetic structure among {groupCount} {groups} at locus {locus} was estimated as Weir & "
                + "Cockerham's (1984) θ, from a nested analysis of variance of allele frequencies among {groups}, "
                + "among {unitCount} individuals within {groups}, and within individuals (Weir 1996). "
                + "{permutations}",
            results: "θ = {theta} ({pValue}), F_IS = {fIS} and F_IT = {fIT} "
                + "(σ²_among = {sigmaAmong}, σ²_individuals = {sigmaIndividuals}, σ²_within = {sigmaWithin}).")
    }

    /// The locus, sample sizes and permutation design.
    ///
    /// - Parameter options: The options the analysis runs with.
    /// - Returns: The Methods values.
    public func methodsValues(options: AnalysisOptions) -> [String: String] {
        [
            "locus": locus,
            "groups": groupLabel,
            "unitCount": AnalysisReport.count(individuals.count),
            "groupCount": AnalysisReport.count(strata.count),
            "permutations": AnalysisReport.permutationSentence(options, permuting: "individuals among \(groupLabel)"),
        ]
    }
}
