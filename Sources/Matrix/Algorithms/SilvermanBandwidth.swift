//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  SilvermanBandwidth.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Chooses the bandwidth R's `bw.nrd0` does: Silverman's rule of thumb.
///
/// - Parameter values: The observations; must not be empty.
/// - Returns: `0.9 · min(sd, IQR / 1.34) · n^(-1/5)`, falling back through the
///   standard deviation, `|x₁|` and `1` when the spread is zero, as R does.
public func SilvermanBandwidth(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    let count = Double(sorted.count)
    let mean = sorted.reduce(0, +) / count
    let variance = sorted.count > 1
        ? sorted.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / (count - 1)
        : 0
    let deviation = variance.squareRoot()
    let spread = quantile(sorted, 0.75) - quantile(sorted, 0.25)
    var scale = min(deviation, spread / 1.34)
    if scale == 0 { scale = deviation }
    if scale == 0 { scale = abs(sorted[0]) }
    if scale == 0 { scale = 1 }
    return 0.9 * scale * pow(count, -0.2)
}

/// Finds a quantile by linear interpolation, R's default (type 7).
///
/// - Parameters:
///   - sorted: The observations, in ascending order; must not be empty.
///   - probability: The quantile to find, from `0` to `1`.
/// - Returns: The interpolated quantile.
private func quantile(_ sorted: [Double], _ probability: Double) -> Double {
    let position = probability * Double(sorted.count - 1)
    let lower = Int(position)
    let upper = min(lower + 1, sorted.count - 1)
    return sorted[lower] + (position - Double(lower)) * (sorted[upper] - sorted[lower])
}
