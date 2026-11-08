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

    /// Weir & Cockerham's (1984) θ at one locus, with F_IS and F_IT, from a
    /// nested analysis of variance of allele frequencies.
    public static let weirCockerham = AnalysisType("weirCockerham",
                                                   displayName: "Weir & Cockerham θ",
                                                   operands: [AnalysisOperand(role: "genotypes", kind: .genotypes),
                                                              AnalysisOperand(role: "strata", kind: .partition)],
                                                   usesIterations: true)

    /// Genetic differentiation among strata locus by locus: θ, F_IS and F_IT, Φ_ST, Gst, G′st and Dest, with
    /// multilocus values as ratios of sums over loci.
    public static let geneticDifferentiation = AnalysisType("geneticDifferentiation",
                                                            displayName: "Genetic Differentiation",
                                                            operands: [AnalysisOperand(role: "genotypes",
                                                                                       kind: .genotypes),
                                                                       AnalysisOperand(role: "strata",
                                                                                       kind: .partition)],
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
