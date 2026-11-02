//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  TwoGenerAnalysis+Report.swift
//  PopulationGenetics
//
//  Methods keys: those of `VarianceDecompositionAnalysis` plus `gameteCount`,
//  `motherCount`, `locusCount`, `frequencyMethod` and `dataHandling` (the
//  sentences on ambiguous, imputed and dropped gametes; empty if none).
//  Results keys: those of `VarianceDecompositionOutcome` plus
//  `effectivePollenDonors`.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension TwoGenerAnalysis {

    /// TwoGener (Smouse et al. 2001) wording.
    public static var reportTemplate: AnalysisReportTemplate {
        AnalysisReportTemplate(
            methods: "Pollen pool structure was estimated with the TwoGener analysis (Smouse et al. 2001). The "
                + "paternal gamete of each of {gameteCount} offspring from {motherCount} mothers was recovered at "
                + "{locusCount} loci by removing the maternal contribution, and scored as a vector of allele "
                + "indicators. Pollen-pool allele frequencies were estimated across all paternal gametes by "
                + "{frequencyMethod}.{dataHandling} Heterogeneity among the pollen pools sampled by different "
                + "mothers was estimated as Φ_FT from an analysis of molecular variance (AMOVA; Excoffier, Smouse "
                + "& Quattro 1992) of the squared distances between paternal gametes, with mothers as groups. "
                + "{permutations}",
            results: "The pollen pools sampled by different mothers differed (Φ_FT = {ratio}, {pValue}), with "
                + "{percentAmong}% of the variation in paternal gametes among mothers, corresponding to an "
                + "effective number of {effectivePollenDonors} pollen donors per mother (N_ep = 1 / 2Φ_FT).")
    }

    /// The sample, the frequency method and how the data were handled.
    ///
    /// - Parameter options: The options the analysis runs with.
    /// - Returns: The Methods values.
    public func methodsValues(options: AnalysisOptions) -> [String: String] {
        var handling: [String] = []
        if gametes.ambiguousCount > 0 {
            handling.append("Where mother and offspring shared a heterozygous genotype "
                            + "(\(AnalysisReport.count(gametes.ambiguousCount)) gamete-loci), the paternal allele "
                            + "was weighted by its pollen-pool posterior probability, qᵢ / (qᵢ + qₖ).")
        }
        if gametes.imputedCount > 0 {
            handling.append("Paternal alleles at \(AnalysisReport.count(gametes.imputedCount)) gamete-loci with a "
                            + "missing maternal or offspring genotype were imputed from the pollen-pool allele "
                            + "frequencies.")
        }
        if gametes.droppedCount > 0 {
            handling.append("\(AnalysisReport.count(gametes.droppedCount)) offspring that shared no allele with "
                            + "their mother at one or more loci were excluded.")
        }
        if gametes.motherlessOffspringCount > 0 {
            handling.append("\(AnalysisReport.count(gametes.motherlessOffspringCount)) offspring in families "
                            + "without a genotyped mother were excluded.")
        }

        var values = amova.methodsValues(options: options)
        values["gameteCount"] = AnalysisReport.count(offspring.count)
        values["motherCount"] = AnalysisReport.count(Set(partition).count)
        values["locusCount"] = AnalysisReport.count(gametes.locusCount)
        values["frequencyMethod"] = switch frequencyMethod {
        case .expectationMaximization:
            "expectation–maximization, weighting each ambiguous paternal allele by its posterior probability"
        case .paternalAverage:
            "the paternal average, counting an ambiguous paternal allele as half of each candidate "
                + "(Smouse et al. 2001)"
        }
        values["dataHandling"] = handling.map { " " + $0 }.joined()
        return values
    }
}
