//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DistanceVarianceDecompositionResult.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.06.28.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// One-level distance-based variance decomposition for a given partition.
public struct DistanceVarianceDecompositionResult: Sendable {
    /// Total sum of squares across all pairs (permutation-invariant).
    public let totalSS: Double
    /// Sum of squares within groups.
    public let withinSS: Double
    /// Sum of squares among groups (= totalSS − withinSS).
    public let amongSS: Double
    /// Number of groups in the partition.
    public let groupCount: Int
    /// Degrees of freedom among groups (= groupCount − 1).
    public let dfAmong: Int
    /// Degrees of freedom within groups (= N − groupCount).
    public let dfWithin: Int
    /// Among-group variance component (σ²_Among).
    public let sigmaAmong: Double
    /// Within-group variance component (σ²_Within).
    public let sigmaWithin: Double
    /// The among/total variance ratio: σ²_Among / (σ²_Among + σ²_Within).
    ///
    /// This is a generic random-effects statistic — the same computation
    /// carries field-specific names elsewhere (e.g. population genetics'
    /// Φ_ST for a multi-locus AMOVA, or Weir & Cockerham's Θ for a
    /// single-locus estimator); consuming packages should expose their own
    /// domain label as a computed property forwarding to this one rather
    /// than this type picking a side.
    public let varianceRatio: Double

    /// Creates a result from precomputed components.
    ///
    /// - Parameters:
    ///   - totalSS: Total sum of squares.
    ///   - withinSS: Within-group sum of squares.
    ///   - amongSS: Among-group sum of squares.
    ///   - groupCount: Number of groups.
    ///   - dfAmong: Among-group degrees of freedom.
    ///   - dfWithin: Within-group degrees of freedom.
    ///   - sigmaAmong: Among-group variance component.
    ///   - sigmaWithin: Within-group variance component.
    ///   - varianceRatio: σ²_Among / (σ²_Among + σ²_Within).
    public init(totalSS: Double, withinSS: Double, amongSS: Double,
                groupCount: Int, dfAmong: Int, dfWithin: Int,
                sigmaAmong: Double, sigmaWithin: Double, varianceRatio: Double) {
        self.totalSS = totalSS
        self.withinSS = withinSS
        self.amongSS = amongSS
        self.groupCount = groupCount
        self.dfAmong = dfAmong
        self.dfWithin = dfWithin
        self.sigmaAmong = sigmaAmong
        self.sigmaWithin = sigmaWithin
        self.varianceRatio = varianceRatio
    }
}
