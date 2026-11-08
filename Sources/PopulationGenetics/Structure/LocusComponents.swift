//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  LocusComponents.swift
//  PopulationGenetics
//
//  Everything a structure table needs from one locus, kept as sums so loci
//  add: each statistic is a numerator and a denominator, and the multilocus
//  value divides their sums over loci rather than averaging the per-locus
//  values.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// The additive pieces of one locus's structure statistics, or of several loci summed.
struct LocusComponents: Sendable, Equatable {

    /// The loci summed.
    var locusCount: Int
    /// The units genotyped, at one locus.
    var units: Int
    /// The alleles seen, at one locus.
    var alleles: Int
    /// The strata with data, at one locus.
    var strata: Int
    /// Hs summed over loci.
    var hsSum: Double
    /// Ht summed over loci.
    var htSum: Double
    /// The AMOVA of gene copies.
    var geneCopies: VarianceParts?
    /// The AMOVA of genotypes.
    var genotypes: VarianceParts?
    /// The AMOVA of paternal gametes.
    var gametes: VarianceParts?
    /// Weir & Cockerham's analysis: among strata, among individuals within strata, within individuals.
    var weirCockerham: VarianceParts?
    /// Each column's numerator, in `StructureSpec.Column.allCases` order.
    var numerators: [Double]
    /// Each column's denominator, in the same order.
    var denominators: [Double]

    /// Mean Hs over the loci.
    var hs: Double { hsSum / Double(locusCount) }
    /// Mean Ht over the loci.
    var ht: Double { htSum / Double(locusCount) }

    /// A column's value: its numerator over its denominator.
    ///
    /// - Parameter column: The statistic.
    /// - Returns: The value, `NaN` where it can't be estimated.
    func value(_ column: StructureSpec.Column) -> Double {
        let i = Self.index[column] ?? 0
        return denominators[i] != 0 ? numerators[i] / denominators[i] : .nan
    }

    /// A variance-components statistic's parts.
    ///
    /// - Parameter statistic: The statistic.
    /// - Returns: Its analysis of variance, if the locus has one.
    func parts(_ statistic: StructureSpec.Statistic) -> VarianceParts? {
        switch statistic {
        case .phiGeneCopies: geneCopies
        case .phiGenotypes: genotypes
        case .theta: weirCockerham
        case .phiGametes: gametes
        }
    }

    /// Each column's position in the numerators and denominators.
    static let index: [StructureSpec.Column: Int] = Dictionary(
        uniqueKeysWithValues: StructureSpec.Column.allCases.enumerated().map { ($1, $0) })

    /// Adds loci.
    ///
    /// - Parameters:
    ///   - lhs: One locus or sum.
    ///   - rhs: Another.
    /// - Returns: The sum; `units`, `alleles` and `strata` keep the larger, since they describe single loci.
    static func + (lhs: LocusComponents, rhs: LocusComponents) -> LocusComponents {
        LocusComponents(locusCount: lhs.locusCount + rhs.locusCount, units: max(lhs.units, rhs.units),
                        alleles: max(lhs.alleles, rhs.alleles), strata: max(lhs.strata, rhs.strata),
                        hsSum: lhs.hsSum + rhs.hsSum, htSum: lhs.htSum + rhs.htSum,
                        geneCopies: lhs.geneCopies + rhs.geneCopies, genotypes: lhs.genotypes + rhs.genotypes,
                        gametes: lhs.gametes + rhs.gametes, weirCockerham: lhs.weirCockerham + rhs.weirCockerham,
                        numerators: zip(lhs.numerators, rhs.numerators).map(+),
                        denominators: zip(lhs.denominators, rhs.denominators).map(+))
    }
}
