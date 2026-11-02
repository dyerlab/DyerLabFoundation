//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RarefactionAnalysis+Report.swift
//  Matrix
//
//  Methods keys: `statisticLabel`, `units`, `sampleSize`, `size`,
//  `iterations`. Results keys (from `RarefactionOutcome`): `mean`,
//  `interval`, `fullSample`, `size`.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

extension RarefactionAnalysis {

    /// Rarefaction wording.
    public static var reportTemplate: AnalysisReportTemplate {
        AnalysisReportTemplate(
            methods: "To compare samples of different size, {statisticLabel} was rarefied: it was re-estimated "
                + "from {iterations} random subsamples of {size} of the {sampleSize} {units}, drawn without "
                + "replacement (random seed {seed}).",
            results: "Rarefied to {size} {units}, {statisticLabel} was {mean} (95% interval {interval}), "
                + "against {fullSample} for all {sampleSize} {units}.")
    }

    /// The sample and subsample sizes.
    ///
    /// - Parameter options: The options the analysis runs with.
    /// - Returns: The Methods values.
    public func methodsValues(options: AnalysisOptions) -> [String: String] {
        [
            "statisticLabel": statisticLabel,
            "units": unitLabel,
            "sampleSize": AnalysisReport.count(population.count),
            "size": AnalysisReport.count(size),
        ]
    }
}
