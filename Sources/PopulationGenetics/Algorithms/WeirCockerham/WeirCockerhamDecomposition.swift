//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  WeirCockerhamDecomposition.swift
//  PopulationGenetics
//
//  Weir & Cockerham's (1984) estimator written as the nested analysis of
//  variance of allele indicators in Weir (1996, Genetic Data Analysis II,
//  ch. 5): among strata (MSP), among individuals within strata (MSI) and
//  between the two alleles within individuals (MSG), each summed over alleles.
//  The components are a = (MSP − MSI)/2n_c, b = (MSI − MSG)/2 and c = MSG.
//  This form reproduces hierfstat::wc() exactly (structure_fixtures.json), and
//  it gives the sums of squares the structure table shows.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// Weir & Cockerham's variance components at one locus, with the nested analysis of variance behind them.
public struct WeirCockerhamDecomposition: Sendable, Equatable {

    /// The number of strata with at least one genotyped individual.
    public let strataCount: Int
    /// The number of individuals genotyped at the locus.
    public let individualCount: Int
    /// The average stratum size corrected for unequal sizes, n_c.
    public let nc: Double

    /// The mean square among strata, summed over alleles.
    public let msAmong: Double
    /// The mean square among individuals within strata, summed over alleles.
    public let msIndividuals: Double
    /// The mean square between alleles within individuals, summed over alleles.
    public let msWithin: Double

    // MARK: - Degrees of freedom

    /// Degrees of freedom among strata, `r − 1`.
    public var dfAmong: Int { strataCount - 1 }
    /// Degrees of freedom among individuals within strata, `N − r`.
    public var dfIndividuals: Int { individualCount - strataCount }
    /// Degrees of freedom within individuals, `N`.
    public var dfWithin: Int { individualCount }
    /// Total degrees of freedom over the `2N` alleles, `2N − 1`.
    public var dfTotal: Int { 2 * individualCount - 1 }

    // MARK: - Sums of squares

    /// The sum of squares among strata.
    public var ssAmong: Double { msAmong * Double(dfAmong) }
    /// The sum of squares among individuals within strata.
    public var ssIndividuals: Double { msIndividuals * Double(dfIndividuals) }
    /// The sum of squares within individuals.
    public var ssWithin: Double { msWithin * Double(dfWithin) }
    /// The total sum of squares.
    public var ssTotal: Double { ssAmong + ssIndividuals + ssWithin }

    // MARK: - Components and F-statistics

    /// The variance component among strata, `a`.
    public var sigmaAmong: Double { (msAmong - msIndividuals) / (2 * nc) }
    /// The variance component among individuals within strata, `b`.
    public var sigmaIndividuals: Double { (msIndividuals - msWithin) / 2 }
    /// The variance component within individuals, `c`.
    public var sigmaWithin: Double { msWithin }

    /// θ (F_ST), `a / (a + b + c)`.
    public var theta: Double { sigmaAmong / (sigmaAmong + sigmaIndividuals + sigmaWithin) }
    /// F_IS, `b / (b + c)`.
    public var fIS: Double { sigmaIndividuals / (sigmaIndividuals + sigmaWithin) }
    /// F_IT, `(a + b) / (a + b + c)`.
    public var fIT: Double { (sigmaAmong + sigmaIndividuals) / (sigmaAmong + sigmaIndividuals + sigmaWithin) }

    // MARK: - Initialization

    /// Computes the decomposition for diploid genotypes.
    ///
    /// - Parameters:
    ///   - first: Each individual's first allele index.
    ///   - second: Each individual's second allele index, in the same order.
    ///   - partition: Each individual's stratum, as `0..<strataCount`.
    ///   - strataCount: The number of strata; each must hold at least one individual.
    ///   - alleleSlots: One more than the largest allele index.
    /// - Precondition: The arrays are the same length, and there are more individuals than strata.
    init(first: [UInt8], second: [UInt8], partition: [Int], strataCount: Int, alleleSlots: Int) {
        precondition(first.count == second.count && first.count == partition.count,
                     "WeirCockerhamDecomposition: genotype and partition lengths differ")
        precondition(first.count > strataCount && strataCount >= 2,
                     "WeirCockerhamDecomposition: needs two strata and more individuals than strata")
        let r = strataCount
        var n = [Double](repeating: 0, count: r)
        // copies[i][u]: copies of allele u in stratum i; heterozygotes[i][u]: heterozygotes carrying u.
        var copies = [[Double]](repeating: [Double](repeating: 0, count: alleleSlots), count: r)
        var heterozygotes = copies
        for k in partition.indices {
            let i = partition[k], a = Int(first[k]), b = Int(second[k])
            n[i] += 1
            copies[i][a] += 1
            copies[i][b] += 1
            if a != b {
                heterozygotes[i][a] += 1
                heterozygotes[i][b] += 1
            }
        }
        let total = n.reduce(0, +)
        let nc = (total - n.reduce(0) { $0 + $1 * $1 } / total) / Double(r - 1)

        var msAmong = 0.0, msIndividuals = 0.0, msWithin = 0.0
        for u in 0..<alleleSlots {
            var pBar = 0.0
            for i in 0..<r { pBar += copies[i][u] / 2 }
            guard pBar > 0 else { continue }
            pBar /= total
            var among = 0.0, individuals = 0.0, within = 0.0
            for i in 0..<r where n[i] > 0 {
                let p = copies[i][u] / (2 * n[i])
                let h = heterozygotes[i][u] / n[i]
                among += 2 * n[i] * (p - pBar) * (p - pBar)
                individuals += n[i] * (2 * p * (1 - p) - h / 2)
                within += n[i] * h
            }
            msAmong += among / Double(r - 1)
            msIndividuals += individuals / (total - Double(r))
            msWithin += within / (2 * total)
        }

        self.strataCount = r
        self.individualCount = Int(total)
        self.nc = nc
        self.msAmong = msAmong
        self.msIndividuals = msIndividuals
        self.msWithin = msWithin
    }
}
