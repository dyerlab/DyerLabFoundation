//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AMOVA.swift
//  PopulationGenetics
//
//  Domain vocabulary layered onto Matrix's DistanceVarianceDecomposition —
//  the distance-based random-effects variance decomposition population
//  genetics calls AMOVA. The computation itself lives in Matrix precisely
//  because it has no genetics content; this file is the thin translation
//  layer back to this field's names, per the same reasoning documented on
//  `DistanceVarianceDecompositionResult.varianceRatio` and `AnalysisTag`
//  (Matrix): the foundation stays domain-neutral, every field picks its own
//  vocabulary as an extension.
//
//  Created by Rodney Dyer on 2026.07.14.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// Analysis of molecular variance: the population-genetics name for `DistanceVarianceDecomposition`.
public typealias AMOVA = DistanceVarianceDecomposition
/// The result of an ``AMOVA``.
public typealias AMOVAResult = DistanceVarianceDecompositionResult
/// A progress snapshot from an ``AMOVA`` permutation test.
public typealias AMOVAPermutationProgress = DistanceVarianceDecompositionProgress

extension AMOVAResult {
    /// Population genetics' Φ_ST — this field's label for the generic
    /// among/total variance ratio, used for every AMOVA in this package
    /// (individuals or paternal gametes) rather than GenAlEx's Φ_PT.
    ///
    /// Weir & Cockerham's θ is *not* this ratio for one locus: a genotype-level
    /// AMOVA has no within-individual level, so it departs from θ whenever
    /// genotypes depart from Hardy–Weinberg. θ is ``WeirCockerhamAnalysis``.
    public var phi: Double { varianceRatio }
}

extension AnalysisTag {
    /// This package's label for `AMOVA.permutationTest` — a multi-locus
    /// distance-based variance decomposition. See `AMOVAResult.phi`.
    public static let amovaPhiST = AnalysisTag("amovaPhiST")

    /// This package's label for Weir & Cockerham's θ (``WeirCockerhamAnalysis``):
    /// the among-strata share of a nested analysis of variance of allele
    /// indicators, with individuals within strata and alleles within individuals.
    public static let weirCockerhamTheta = AnalysisTag("weirCockerhamTheta")

    /// This package's label for a by-locus structure table: θ, Φ_ST, Gst, G′st and Dest at each locus, with
    /// multilocus ratios of sums (`StructureAnalysis`).
    public static let differentiationByLocus = AnalysisTag("differentiationByLocus")

    /// This package's label for 2Gener's Φ_FT — AMOVA among the paternal
    /// gametes of different mothers (Smouse et al. 2001).
    public static let twoGenerPhiFT = AnalysisTag("twoGenerPhiFT")

    /// This package's label for rarefaction at a specific diversity metric.
    /// Unlike `.amovaPhiST`, this encodes real data (`type`) into the tag's
    /// `rawValue` — different diversity metrics need distinguishable tags,
    /// so a single constant wouldn't do.
    ///
    /// - Parameter type: The diversity metric being rarefied.
    /// - Returns: A tag such as `rarefaction.A`.
    public static func rarefaction(_ type: DiversityType) -> AnalysisTag {
        AnalysisTag("rarefaction.\(type)")
    }
}
