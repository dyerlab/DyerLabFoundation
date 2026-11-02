//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DiversityRarefactionAnalysis+Report.swift
//  PopulationGenetics
//
//  Uses Matrix's rarefaction wording (`RarefactionAnalysis.reportTemplate`)
//  with the diversity measure named and the resampled unit described.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension DiversityRarefactionAnalysis {

    /// Rarefaction wording for a genetic diversity measure.
    public static var reportTemplate: AnalysisReportTemplate {
        AnalysisReportTemplate(
            methods: "To compare samples of different size, {statisticLabel} was rarefied: it was re-estimated "
                + "from {iterations} random subsamples of {size} of the {sampleSize} individuals, {resampling} "
                + "(random seed {seed}).",
            results: "Rarefied to {size} individuals, {statisticLabel} was {mean} (95% interval {interval}), "
                + "against {fullSample} for all {sampleSize} individuals.")
    }

    /// The diversity measure, the sample and subsample sizes and how
    /// subsamples were drawn.
    ///
    /// - Parameter options: The options the analysis runs with.
    /// - Returns: The Methods values.
    public func methodsValues(options: AnalysisOptions) -> [String: String] {
        [
            "statisticLabel": diversityName,
            "sampleSize": AnalysisReport.count(genotypes.count),
            "size": AnalysisReport.count(size),
            "resampling": individualBased || diversityType.level == .Genotypic
                ? "drawing whole individuals without replacement"
                : "drawing the alleles of that many individuals from the pooled alleles of the sample",
        ]
    }

    /// The diversity measure's name for running text.
    private var diversityName: String {
        switch diversityType {
        case .A: "allelic richness (A)"
        case .A95: "the number of alleles with frequency of at least 5% (A95)"
        case .Ae: "the effective number of alleles (Ae)"
        case .Ho: "observed heterozygosity (Ho)"
        case .He: "expected heterozygosity (He)"
        default: diversityType.rawValue
        }
    }
}
