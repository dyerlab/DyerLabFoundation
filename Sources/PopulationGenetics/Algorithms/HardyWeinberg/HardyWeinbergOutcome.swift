//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  HardyWeinbergOutcome.swift
//  PopulationGenetics
//
//  The result of a `HardyWeinbergAnalysis`: one row of gstudio's hwe.test()
//  table (Stratum, Locus, statistic, df, p.value, method).
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// The chi-square test of Hardy–Weinberg proportions at one locus.
public struct HardyWeinbergOutcome: AnalysisOutcome {

    /// The locus's name.
    public let locus: String

    /// The stratum tested, or `nil` for the individuals as a whole.
    public let stratum: String?

    /// The chi-square statistic, Σ (|O − E| − c)² / E with c = ½ when ``isCorrected``.
    public let statistic: Double

    /// The degrees of freedom, ℓ(ℓ − 1)/2 for ℓ alleles.
    public let degreesOfFreedom: Int

    /// The upper-tail chi-square P.
    public let pValue: Double?

    /// Whether the continuity correction was applied.
    public let isCorrected: Bool

    /// The individuals genotyped.
    public let sampleSize: Int

    /// The observed and expected count of every genotype.
    public let counts: [GenotypeCount]

    /// Always `AnalysisType.hardyWeinberg`.
    public var analysisType: AnalysisType { .hardyWeinberg }

    /// `AnalysisType.hardyWeinberg`'s tag.
    public var tag: AnalysisTag { AnalysisType.hardyWeinberg.tag }

    /// The method, as gstudio's `method` column gives it.
    public var method: String {
        "Chi-square test for Hardy-Weinberg equilibrium" + (isCorrected ? " with continuity correction" : "")
    }

    /// Creates an outcome.
    ///
    /// - Parameters:
    ///   - locus: The locus's name.
    ///   - stratum: The stratum, or `nil`.
    ///   - statistic: The chi-square statistic.
    ///   - degreesOfFreedom: Its degrees of freedom.
    ///   - pValue: Its upper-tail P.
    ///   - isCorrected: Whether the continuity correction was applied.
    ///   - sampleSize: The individuals genotyped.
    ///   - counts: The genotype counts.
    public init(locus: String, stratum: String?, statistic: Double, degreesOfFreedom: Int, pValue: Double?,
                isCorrected: Bool, sampleSize: Int, counts: [GenotypeCount]) {
        self.locus = locus
        self.stratum = stratum
        self.statistic = statistic
        self.degreesOfFreedom = degreesOfFreedom
        self.pValue = pValue
        self.isCorrected = isCorrected
        self.sampleSize = sampleSize
        self.counts = counts
    }
}
