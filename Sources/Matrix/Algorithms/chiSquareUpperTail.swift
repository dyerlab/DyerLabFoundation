//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  chiSquareUpperTail.swift
//  Matrix
//
//  R's pchisq(x, df, lower.tail = FALSE), as Q(df/2, x/2).
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// The probability that a chi-square variable exceeds `x`, R's `pchisq(x, df, lower.tail = FALSE)`.
///
/// - Parameters:
///   - x: The statistic.
///   - degreesOfFreedom: The degrees of freedom (`> 0`).
/// - Returns: `P(χ²_df > x)`: `1` for `x ≤ 0`, `NaN` when the degrees of freedom aren't positive.
public func chiSquareUpperTail(_ x: Double, degreesOfFreedom: Double) -> Double {
    guard degreesOfFreedom > 0, !x.isNaN else { return .nan }
    return x <= 0 ? 1 : regularizedUpperIncompleteGamma(degreesOfFreedom / 2, x / 2)
}
