//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StrataRarefactionRow.swift
//  PopulationGenetics
//
//  One row of gstudio's rarefaction.test() table: a statistic at one locus
//  (or the multilocus value) in one stratum, observed on every individual and
//  re-estimated on each subsample of the common size.
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// A diversity statistic in one stratum, observed and rarefied.
public struct StrataRarefactionRow: Sendable, Identifiable {

    /// The stratum.
    public let stratum: String

    /// The locus, or `nil` for the multilocus row.
    public let locus: String?

    /// The statistic.
    public let statistic: DiversityType

    /// The individuals genotyped at the locus in the stratum (`nil` for the multilocus row).
    public let individuals: Int?

    /// The subsample size (`nil` for the multilocus row).
    public let size: Int?

    /// The statistic on every individual genotyped, or `nil` where it is undefined.
    public let observed: Double?

    /// The statistic on each subsample, in draw order; `NaN` where undefined. All `NaN` when the stratum has fewer
    /// individuals than the subsample size; all ``observed`` when it has exactly that many.
    public let values: [Double]

    /// The coverage of ``interval``, e.g. 0.95.
    public let confidenceLevel: Double

    /// Creates a row.
    ///
    /// - Parameters:
    ///   - stratum: The stratum.
    ///   - locus: The locus, or `nil` for the multilocus row.
    ///   - statistic: The statistic.
    ///   - individuals: The individuals genotyped.
    ///   - size: The subsample size.
    ///   - observed: The statistic on every individual.
    ///   - values: The statistic on each subsample.
    ///   - confidenceLevel: The interval's coverage.
    public init(stratum: String, locus: String?, statistic: DiversityType, individuals: Int?, size: Int?,
                observed: Double?, values: [Double], confidenceLevel: Double) {
        self.stratum = stratum
        self.locus = locus
        self.statistic = statistic
        self.individuals = individuals
        self.size = size
        self.observed = observed
        self.values = values
        self.confidenceLevel = confidenceLevel
    }

    /// The stratum, locus and statistic.
    public var id: String { "\(stratum)|\(locus ?? "Multilocus")|\(statistic.rawValue)" }

    /// The mean of the subsample values, gstudio's `estimate`, or `nil` if any is undefined.
    public var estimate: Double? {
        guard !values.isEmpty, values.allSatisfy(\.isFinite) else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// The central ``confidenceLevel`` percentile interval of the subsample values (R's type-7 quantiles), or
    /// `nil` if any is undefined.
    public var interval: ClosedRange<Double>? {
        guard !values.isEmpty, values.allSatisfy(\.isFinite) else { return nil }
        let alpha = (1 - confidenceLevel) / 2
        return empiricalQuantile(values, probability: alpha)...empiricalQuantile(values, probability: 1 - alpha)
    }
}
