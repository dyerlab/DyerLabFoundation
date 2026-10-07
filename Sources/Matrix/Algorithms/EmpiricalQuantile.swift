//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  EmpiricalQuantile.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  R's default sample-quantile estimator (`stats::quantile(type = 7)`) —
//  linear interpolation between order statistics. Added to support the
//  resampling confidence intervals in `asymmetry_ci()` (formerly `asymmetry_jackknife()`).
//

import Foundation

/// R's `stats::quantile(x, probs, type = 7)` (the default type) for a single
/// probability: linear interpolation between order statistics, `h = (n-1)·p + 1`
/// (1-based).
///
/// - Parameters:
///   - values: The sample. Need not be sorted.
///   - probability: A value in `[0, 1]`.
/// - Returns: The interpolated quantile, or `.nan` if `values` is empty.
public func EmpiricalQuantile(_ values: [Double], probability: Double) -> Double {
    guard !values.isEmpty else { return .nan }
    let sorted = values.sorted()
    guard sorted.count > 1 else { return sorted[0] }

    let h = Double(sorted.count - 1) * probability
    let lo = Int(floor(h))
    let hi = min(lo + 1, sorted.count - 1)
    let frac = h - Double(lo)
    return sorted[lo] + frac * (sorted[hi] - sorted[lo])
}
