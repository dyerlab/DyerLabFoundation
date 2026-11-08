//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StructureTableRow.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// One source of variation in a structure table.
public struct StructureTableRow: Sendable, Equatable {

    /// The source of variation within the smallest unit.
    public static let errorSource = "Error"
    /// All the variation.
    public static let totalSource = "Total"
    /// Weir & Cockerham's source among individuals within strata.
    public static let individualSource = "Individual"

    /// The source of variation: a stratum level, ``individualSource``, ``errorSource`` or ``totalSource``.
    public let source: String
    /// Degrees of freedom, or `nil` for loci summed with different degrees of freedom.
    public let df: Int?
    /// The sum of squares.
    public let ss: Double
    /// The mean square, if the row has one.
    public let ms: Double?
    /// The variance component, if the row has one.
    public let sigma: Double?
    /// The row's F-statistic or Φ-statistic, if it has one.
    public let statistic: Double?
    /// The statistic's permutation probability, if it was tested.
    public let p: Double?

    /// Creates a row.
    ///
    /// - Parameters:
    ///   - source: The source of variation.
    ///   - df: Degrees of freedom, if there is one value.
    ///   - ss: The sum of squares.
    ///   - ms: The mean square, if the row has one.
    ///   - sigma: The variance component, if the row has one.
    ///   - statistic: The row's statistic, if it has one.
    ///   - p: The statistic's permutation probability, if it was tested.
    public init(source: String, df: Int?, ss: Double, ms: Double? = nil, sigma: Double? = nil,
                statistic: Double? = nil, p: Double? = nil) {
        self.source = source
        self.df = df
        self.ss = ss
        self.ms = ms
        self.sigma = sigma
        self.statistic = statistic
        self.p = p
    }
}
