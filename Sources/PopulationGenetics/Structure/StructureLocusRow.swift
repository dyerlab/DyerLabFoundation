//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StructureLocusRow.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// One row of a by-locus structure table: a locus, or the multilocus ratios of sums.
public struct StructureLocusRow: Sendable, Equatable {

    /// The name of the multilocus row.
    public static let multilocusName = "Multilocus"

    /// The locus, or ``multilocusName``.
    public let locus: String
    /// The units genotyped: at the locus, or in the analysis for the multilocus row.
    public let units: Int
    /// The alleles seen at the locus, or `nil` for the multilocus row.
    public let alleles: Int?
    /// The diversity within strata, by the spec's estimator, the mean over loci for the multilocus row; `nil`
    /// for gametes.
    public let hs: Double?
    /// The total diversity, by the spec's estimator, the mean over loci for the multilocus row; `nil` for
    /// gametes.
    public let ht: Double?
    /// The spec's columns' values, in order; `nil` where a value can't be estimated.
    public let values: [Double?]
    /// The tested columns' permutation probabilities, in order, if the table was tested.
    public let p: [Double?]
    /// The statistics flagged at this locus and why, such as `"Gst: 13 alleles"`.
    public let concerns: [String]

    /// Creates a row.
    ///
    /// - Parameters:
    ///   - locus: The locus, or ``multilocusName``.
    ///   - units: The units genotyped.
    ///   - alleles: The alleles seen, if a single locus.
    ///   - hs: The diversity within strata.
    ///   - ht: The total diversity.
    ///   - values: The columns' values.
    ///   - p: The tested columns' probabilities.
    ///   - concerns: The statistics flagged and why.
    public init(locus: String, units: Int, alleles: Int?, hs: Double?, ht: Double?, values: [Double?],
                p: [Double?] = [], concerns: [String] = []) {
        self.locus = locus
        self.units = units
        self.alleles = alleles
        self.hs = hs
        self.ht = ht
        self.values = values
        self.p = p
        self.concerns = concerns
    }
}
