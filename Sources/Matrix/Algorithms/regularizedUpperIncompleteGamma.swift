//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  regularizedUpperIncompleteGamma.swift
//  Matrix
//
//  Q(a, x) = Γ(a, x) / Γ(a), by the series for P(a, x) when x < a + 1 and the
//  Lentz continued fraction for Q otherwise (Numerical Recipes, §6.2). It is
//  the upper tail of the chi-square distribution, Q(df/2, x/2), which
//  `chiSquareUpperTail` wraps for R's pchisq(lower.tail = FALSE).
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The regularized upper incomplete gamma function `Q(a, x) = Γ(a, x) / Γ(a)`.
///
/// Accurate to near machine precision for `a > 0` and `x ≥ 0`.
///
/// - Parameters:
///   - a: The shape (`> 0`).
///   - x: The lower limit of integration (`≥ 0`).
/// - Returns: `Q(a, x)` in `[0, 1]`, or `NaN` for `a ≤ 0`, `x < 0` or non-finite input.
public func regularizedUpperIncompleteGamma(_ a: Double, _ x: Double) -> Double {
    guard a > 0, x >= 0, a.isFinite, !x.isNaN else { return .nan }
    if x == 0 { return 1 }
    if x == .infinity { return 0 }
    let logPrefix = a * log(x) - x - lgamma(a)
    if x < a + 1 {
        // Series for P(a, x).
        var term = 1 / a, sum = term, n = a
        for _ in 0..<10_000 {
            n += 1
            term *= x / n
            sum += term
            if abs(term) < abs(sum) * 1e-17 { break }
        }
        return max(0, 1 - sum * exp(logPrefix))
    }
    // Continued fraction for Q(a, x) (modified Lentz).
    let tiny = 1e-300
    var b = x + 1 - a, c = 1 / tiny, d = 1 / b, h = d
    for i in 1..<10_000 {
        let an = -Double(i) * (Double(i) - a)
        b += 2
        d = an * d + b
        if abs(d) < tiny { d = tiny }
        c = b + an / c
        if abs(c) < tiny { c = tiny }
        d = 1 / d
        let delta = d * c
        h *= delta
        if abs(delta - 1) < 1e-16 { break }
    }
    return min(1, exp(logPrefix) * h)
}
