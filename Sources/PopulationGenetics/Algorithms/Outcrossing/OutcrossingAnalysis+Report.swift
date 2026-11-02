//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  OutcrossingAnalysis+Report.swift
//  PopulationGenetics
//
//  Methods keys: `offspringCount`, `familyCount`, `loci`, `steps`, `burnIn`,
//  `thinning`, `nullAlleles`. Results keys (from `Outcrossing.Result`): `t`,
//  `F`, `sampleCount`.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension OutcrossingAnalysis {

    /// Mixed-mating model wording. Check the BORICE citation before
    /// publishing.
    public static var reportTemplate: AnalysisReportTemplate {
        AnalysisReportTemplate(
            methods: "The population outcrossing rate (t) was estimated under the mixed-mating model (Ritland & "
                + "Jain 1981) from {offspringCount} offspring in {familyCount} maternal families at {loci}, by "
                + "Markov chain Monte Carlo sampling of the joint posterior of t, maternal inbreeding histories "
                + "and allele frequencies (as in BORICE; Koelling, Monnahan & Kelly 2012).{nullAlleles} The chain "
                + "ran {steps} steps, the first {burnIn} discarded as burn-in and every {thinning}th step retained "
                + "thereafter (random seed {seed}).",
            results: "The posterior mean outcrossing rate was t = {t} (95% credible interval {interval}), and the "
                + "mean maternal inbreeding coefficient was F = {F} ({sampleCount} posterior samples).")
    }

    /// The sample, the loci and the chain's settings.
    ///
    /// - Parameter options: The options the analysis runs with (its seed).
    /// - Returns: The Methods values.
    public func methodsValues(options: AnalysisOptions) -> [String: String] {
        let nullCount = hasNullModel.map { flags in
            locus.map { flags[$0] ? 1 : 0 } ?? flags.filter { $0 }.count
        } ?? 0
        return [
            "offspringCount": AnalysisReport.count(design.offspringOrdinals.count),
            "familyCount": AnalysisReport.count(design.families.count),
            "loci": locus.map { "locus \(matrix.loci[$0].name)" }
                ?? "\(AnalysisReport.count(matrix.locusCount)) loci",
            "steps": AnalysisReport.count(parameters.numSteps),
            "burnIn": AnalysisReport.count(parameters.burnIn),
            "thinning": AnalysisReport.count(parameters.thinning),
            "nullAlleles": nullCount > 0
                ? " A null allele was modelled at \(nullCount == 1 ? "one locus" : "\(nullCount) loci")." : "",
        ]
    }
}
