//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  DistanceVarianceDecompositionProgress.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 6/28/26.
//

/// A running snapshot of a permutation test, emitted as permutations accrue.
///
/// Lets a UI plot the p-value converging to its asymptote, reinforcing that the
/// estimate settles rather than requiring a fixed magic iteration count.
public struct DistanceVarianceDecompositionProgress: Sendable {
    /// Permutations completed so far.
    public let iteration: Int
    /// The observed (unpermuted) variance ratio.
    public let observedRatio: Double
    /// Number of permuted ratios ≥ observed so far.
    public let exceedances: Int
    /// The most recent permuted variance ratio.
    public let lastRatio: Double
    /// Running mean of the permuted ratios (the settling null centre).
    public let runningMeanRatio: Double
    /// Running one-sided p-value with the standard +1 correction.
    public var pValue: Double { Double(exceedances + 1) / Double(iteration + 1) }
}
