//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  HardyWeinbergAnalysis+Report.swift
//  PopulationGenetics
//
//  Methods keys: `locus`, `where` (" in <stratum>" or empty), `sampleSize`,
//  `alleleCount`, `genotypeCount` and `correction` (a sentence, or empty).
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension HardyWeinbergAnalysis {

    /// Chi-square Hardy–Weinberg wording.
    public static var reportTemplate: AnalysisReportTemplate {
        AnalysisReportTemplate(
            methods: "Departure from Hardy–Weinberg proportions at {locus}{where} was tested with a chi-square "
                + "goodness-of-fit test of the genotype counts of {sampleSize} individuals against those expected "
                + "from their {alleleCount} allele frequencies, over all {genotypeCount} possible genotypes.{correction}",
            results: "Genotype counts at {locus}{where} {departure} Hardy–Weinberg proportions (χ² = {statistic}, "
                + "df = {df}, {pValue}).")
    }

    /// The locus, the sample and the correction.
    ///
    /// - Parameter options: Unused; the test is analytic.
    /// - Returns: The Methods values.
    public func methodsValues(options: AnalysisOptions) -> [String: String] {
        [
            "locus": locus,
            "where": stratum.map { " in \($0)" } ?? "",
            "sampleSize": AnalysisReport.count(sampleSize),
            "alleleCount": AnalysisReport.count(alleleCount),
            "genotypeCount": AnalysisReport.count(counts.count),
            "correction": isCorrected
                ? " Because some genotypes were expected fewer than five times, Yates' continuity correction was "
                    + "applied."
                : "",
        ]
    }
}
