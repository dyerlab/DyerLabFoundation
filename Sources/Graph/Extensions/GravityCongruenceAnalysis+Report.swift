//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GravityCongruenceAnalysis+Report.swift
//  Graph
//
//  Methods keys: `populationCount`, `sharedEdgeCount`, `gamma` (one value, or
//  both when they differ) and `permutations`.
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension GravityCongruenceAnalysis {

    /// Gravity congruence wording.
    public static var reportTemplate: AnalysisReportTemplate {
        AnalysisReportTemplate(
            methods: "Congruence of gene flow between two Population Graphs over the same {populationCount} "
                + "populations was assessed from each graph's genetic gravity, computed on its own topology with "
                + "{gamma}. Source-sink scores (S) were compared by Spearman's rank correlation, since S is not on "
                + "a common scale across graphs. {permutations} The direction of gene flow was compared over the "
                + "{sharedEdgeCount} edges present in both graphs as the proportion whose asymmetry Δ had the same "
                + "sign in both, tested against one half with an exact binomial (sign) test that treats edges as "
                + "independent; edges with Δ = 0 in either graph were left out.",
            results: "Source-sink scores were {rhoAgreement} between the graphs (Spearman's ρ = {rho}, {pValue}). "
                + "Gene flow ran the same way along {concordantEdges} of {directedEdges} shared edges with a "
                + "direction in both ({edgeConcordance}, sign test {edgePValue}).")
    }

    /// The populations, the shared edges, the bandwidths and the permutations.
    ///
    /// - Parameter options: The options the analysis runs with.
    /// - Returns: The Methods values.
    public func methodsValues(options: AnalysisOptions) -> [String: String] {
        [
            "populationCount": AnalysisReport.count(nodes.count),
            "sharedEdgeCount": AnalysisReport.count(edges.count),
            "gamma": gamma1 == gamma2
                ? "bandwidth multiplier γ = \(AnalysisReport.number(gamma1))"
                : "bandwidth multipliers γ = \(AnalysisReport.number(gamma1)) and \(AnalysisReport.number(gamma2))",
            "permutations": options.iterations > 0
                ? AnalysisReport.permutationSentence(options, permuting: "the second graph's population labels")
                : "",
        ]
    }
}
