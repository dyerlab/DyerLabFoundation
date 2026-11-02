//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AnalysisType+PopulationGenetics.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension AnalysisType {

    /// Mating-system estimation: the posterior outcrossing rate (`t`) and
    /// inbreeding coefficient from maternal families, by MCMC.
    public static let outcrossing = AnalysisType("outcrossing",
                                                 displayName: "Outcrossing Rate",
                                                 operands: [AnalysisOperand(role: "genotypes", kind: .genotypes),
                                                            AnalysisOperand(role: "families", kind: .families)],
                                                 usesIterations: false)

    /// Correlated paternity (`r_p`): the probability that two sibs share a
    /// father, and from it the effective number of pollen donors.
    public static let correlatedPaternity = AnalysisType("correlatedPaternity",
                                                         displayName: "Correlated Paternity",
                                                         operands: [AnalysisOperand(role: "genotypes",
                                                                                    kind: .genotypes),
                                                                    AnalysisOperand(role: "families",
                                                                                    kind: .families)],
                                                         usesIterations: false)

    /// Isolation by distance (Rousset 1997): linearized pairwise
    /// differentiation, `F / (1 − F)`, against spatial separation, tested by a
    /// Mantel permutation test.
    public static let isolationByDistance = AnalysisType("isolationByDistance",
                                                         displayName: "Isolation by Distance",
                                                         operands: [AnalysisOperand(role: "differentiation",
                                                                                    kind: .pairwise),
                                                                    AnalysisOperand(role: "separation",
                                                                                    kind: .pairwise)],
                                                         usesIterations: true)

    /// Two-generation analysis of pollen pool structure (2Gener; Smouse et al.
    /// 2001): AMOVA of the paternal gametes recovered from mothers and their
    /// offspring, with mothers as strata, giving Φ_FT.
    public static let twoGener = AnalysisType("twoGener",
                                              displayName: "TwoGener",
                                              operands: [AnalysisOperand(role: "genotypes", kind: .genotypes),
                                                         AnalysisOperand(role: "families", kind: .families)],
                                              usesIterations: true)
}
