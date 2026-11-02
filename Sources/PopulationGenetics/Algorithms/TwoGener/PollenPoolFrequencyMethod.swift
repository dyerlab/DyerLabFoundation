//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PollenPoolFrequencyMethod.swift
//  PopulationGenetics
//
//  Both methods estimate one set of frequencies for the whole study, from
//  every recovered paternal gamete, as Smouse et al. (2001) recommend; they
//  differ only in how a gamete whose paternal allele is ambiguous (mother and
//  offspring share a heterozygote) is counted.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// How pollen-pool allele frequencies are estimated for a two-generation (2Gener) analysis.
public enum PollenPoolFrequencyMethod: String, Sendable, Codable, CaseIterable {

    /// The original 2Gener estimate (Smouse et al. 2001), as in GenAlEx: an
    /// ambiguous paternal gamete counts half towards each of its two candidate
    /// alleles. Kept for comparison with published analyses.
    case paternalAverage

    /// Maximum-likelihood frequencies by expectation–maximization: starting
    /// from ``paternalAverage``, each ambiguous gamete is counted towards its
    /// candidates in proportion to their current frequencies, `qᵢ / (qᵢ + qₖ)`,
    /// the same posterior used to score the gamete, until the frequencies stop
    /// changing. This is the default: it is self-consistent with the gamete
    /// scoring, where the half-and-half count is not.
    case expectationMaximization
}
