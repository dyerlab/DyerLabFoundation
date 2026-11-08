//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  VarianceParts.swift
//  PopulationGenetics
//
//  The analysis of variance at one locus, or summed over loci. Sums of
//  squares and variance components add across loci; degrees of freedom only
//  when every locus has the same, since loci genotyped in different numbers of
//  individuals have no single df between them.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// Sums of squares, degrees of freedom and variance components, outermost source first.
struct VarianceParts: Sendable, Equatable {

    /// The sums of squares.
    var ss: [Double]
    /// The degrees of freedom, or `nil` where summed loci differ.
    var df: [Int?]
    /// The variance components.
    var sigma: [Double]

    /// The share of the variance among strata: Φ_ST, or θ for Weir & Cockerham's three sources.
    var amongShare: Double { sigma[0] / sigma.reduce(0, +) }

    /// The parts of an analysis of units among strata, from the total and within-strata sums of squares.
    ///
    /// The variance components follow Excoffier et al. (1992): `σ²_within = SS_within/(M − r)` and
    /// `σ²_among = (SS_among/(r − 1) − σ²_within)/n₀`, with `n₀ = (M − Σmᵢ²/M)/(r − 1)`.
    ///
    /// - Parameters:
    ///   - total: The total sum of squares.
    ///   - within: The sum of squares within strata.
    ///   - sizes: The units in each stratum with any.
    /// - Returns: The parts, or `nil` without two strata and more units than strata.
    static func twoLevel(total: Double, within: Double, sizes: [Double]) -> VarianceParts? {
        let r = sizes.count
        let m = sizes.reduce(0, +)
        guard r >= 2, m > Double(r) else { return nil }
        let n0 = (m - sizes.reduce(0) { $0 + $1 * $1 } / m) / Double(r - 1)
        let sigmaWithin = within / (m - Double(r))
        let sigmaAmong = ((total - within) / Double(r - 1) - sigmaWithin) / n0
        return VarianceParts(ss: [total - within, within], df: [r - 1, Int(m) - r],
                             sigma: [sigmaAmong, sigmaWithin])
    }

    /// Adds two loci's parts.
    ///
    /// - Parameters:
    ///   - lhs: One locus or sum.
    ///   - rhs: Another, with the same sources.
    /// - Returns: The sum, with each df kept only where both agree.
    static func + (lhs: VarianceParts, rhs: VarianceParts) -> VarianceParts {
        VarianceParts(ss: zip(lhs.ss, rhs.ss).map(+),
                      df: zip(lhs.df, rhs.df).map { $0 == $1 ? $0 : nil },
                      sigma: zip(lhs.sigma, rhs.sigma).map(+))
    }
}

extension Optional where Wrapped == VarianceParts {
    /// Adds parts that may be missing at a locus.
    ///
    /// - Parameters:
    ///   - lhs: One locus or sum.
    ///   - rhs: Another.
    /// - Returns: Their sum, or whichever is there.
    static func + (lhs: VarianceParts?, rhs: VarianceParts?) -> VarianceParts? {
        switch (lhs, rhs) {
        case let (l?, r?): l + r
        case let (l?, nil): l
        case let (nil, r): r
        }
    }
}
