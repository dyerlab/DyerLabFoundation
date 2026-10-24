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
    /// among/total variance ratio. Weir & Cockerham's Θ (a single-locus
    /// estimator) is the identical statistic under a different subfield's
    /// label; neither name belongs on the foundation type itself.
    public var phi: Double { varianceRatio }
}

extension AnalysisTag {
    /// This package's label for `AMOVA.permutationTest` — a multi-locus
    /// distance-based variance decomposition. See `AMOVAResult.phi`.
    public static let amovaPhiST = AnalysisTag("amovaPhiST")

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
