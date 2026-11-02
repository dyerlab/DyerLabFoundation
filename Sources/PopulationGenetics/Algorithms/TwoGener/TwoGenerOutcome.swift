//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  TwoGenerOutcome.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// The outcome of a ``TwoGenerAnalysis``.
public struct TwoGenerOutcome: AnalysisOutcome {

    /// AMOVA of the paternal gametes with mothers as strata.
    public let amova: VarianceDecompositionOutcome

    /// The study-wide pollen-pool allele frequencies used, per locus and
    /// indexed by allele index (slot 0, the null allele, is always 0). A locus
    /// left out for lack of recovered paternal alleles has an empty array.
    public let pollenPool: [[Double]]

    /// The number of paternal gametes (offspring) analysed.
    public let gameteCount: Int

    /// The number of mothers with at least one analysed offspring.
    public let motherCount: Int

    /// Always `AnalysisType.twoGener`.
    public var analysisType: AnalysisType { .twoGener }

    /// The label this outcome was produced under.
    public var tag: AnalysisTag { amova.tag }

    /// Φ_FT, the among-mother share of paternal gametic variance.
    public var statistic: Double { amova.statistic }

    /// Φ_FT, ``statistic``.
    public var phiFT: Double { amova.statistic }

    /// The effective number of pollen donors per mother, `1 / (2 Φ_FT)`
    /// (Smouse et al. 2001), or `nil` when Φ_FT is not positive.
    public var effectivePollenDonors: Double? {
        phiFT > 0 ? 1 / (2 * phiFT) : nil
    }

    /// The permutation null of Φ_FT, or `nil` if not tested.
    public var distribution: NullDistributionResult? { amova.distribution }
}
