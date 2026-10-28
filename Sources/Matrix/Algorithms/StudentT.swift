//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StudentT.swift
//  Matrix
//
//  Student's t distribution and the regularized incomplete beta function it
//  depends on. Added to support the two-sided Pearson correlation test used by
//  `Graph`'s `TestCongruence` (a port of gstudio's `test_congruence()`), which
//  reproduces R's `cor.test(method = "pearson")` p-value exactly.
//
//  Created by Rodney Dyer on 2026.09.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The regularized incomplete beta function `Iₓ(a, b)`.
///
/// `Iₓ(a, b) = B(x; a, b) / B(a, b)`, the CDF of a Beta(`a`, `b`) random
/// variable evaluated at `x`. Evaluated with a Lentz continued-fraction
/// expansion (Numerical Recipes, §6.4) — accurate to near machine precision
/// for all `a, b > 0` and `x ∈ [0, 1]`.
///
/// - Parameters:
///   - x: Upper limit of integration, clamped to `[0, 1]`.
///   - a: First shape parameter (`> 0`).
///   - b: Second shape parameter (`> 0`).
/// - Returns: `Iₓ(a, b)` in `[0, 1]`.
public func regularizedIncompleteBeta(_ x: Double, _ a: Double, _ b: Double) -> Double {
    guard a > 0, b > 0 else { return .nan }
    if x <= 0 { return 0 }
    if x >= 1 { return 1 }

    let logBeta = lgamma(a + b) - lgamma(a) - lgamma(b)
        + a * log(x) + b * log1p(-x)
    let front = exp(logBeta)

    // The continued fraction converges quickly only on the side of the
    // distribution's mean where the tail is light; use the symmetry
    // Iₓ(a, b) = 1 − I₁₋ₓ(b, a) to always evaluate on that side.
    if x < (a + 1.0) / (a + b + 2.0) {
        return front * betaContinuedFraction(x, a, b) / a
    } else {
        return 1.0 - front * betaContinuedFraction(1.0 - x, b, a) / b
    }
}

/// Lentz's algorithm for the continued fraction in the incomplete beta function.
private func betaContinuedFraction(_ x: Double, _ a: Double, _ b: Double) -> Double {
    let tiny = 1.0e-30
    let epsilon = 3.0e-16
    let maxIterations = 300

    let qab = a + b
    let qap = a + 1.0
    let qam = a - 1.0

    var c = 1.0
    var d = 1.0 - qab * x / qap
    if abs(d) < tiny { d = tiny }
    d = 1.0 / d
    var result = d

    for m in 1...maxIterations {
        let mm = Double(m)
        let m2 = 2.0 * mm

        var numerator = mm * (b - mm) * x / ((qam + m2) * (a + m2))
        d = 1.0 + numerator * d
        if abs(d) < tiny { d = tiny }
        c = 1.0 + numerator / c
        if abs(c) < tiny { c = tiny }
        d = 1.0 / d
        result *= d * c

        numerator = -(a + mm) * (qab + mm) * x / ((a + m2) * (qap + m2))
        d = 1.0 + numerator * d
        if abs(d) < tiny { d = tiny }
        c = 1.0 + numerator / c
        if abs(c) < tiny { c = tiny }
        d = 1.0 / d
        let delta = d * c
        result *= delta

        if abs(delta - 1.0) < epsilon { break }
    }

    return result
}

/// The CDF of Student's t distribution: `P(T ≤ t)` for `T ~ t(df)`.
///
/// Matches R's `pt(t, df)`. Implemented via
/// ``regularizedIncompleteBeta(_:_:_:)`` using
/// `P(T ≤ t) = 1 − ½ I_{df/(df+t²)}(df/2, ½)` for `t > 0` and the mirror
/// image for `t ≤ 0`.
///
/// - Parameters:
///   - t: The value at which to evaluate the CDF.
///   - degreesOfFreedom: `df > 0`.
/// - Returns: `P(T ≤ t)`, or `.nan` if `degreesOfFreedom` is not positive.
public func studentTCDF(_ t: Double, degreesOfFreedom: Double) -> Double {
    guard degreesOfFreedom > 0 else { return .nan }
    if t == 0 { return 0.5 }

    let x = degreesOfFreedom / (degreesOfFreedom + t * t)
    let halfTail = 0.5 * regularizedIncompleteBeta(x, degreesOfFreedom / 2.0, 0.5)
    return t > 0 ? 1.0 - halfTail : halfTail
}

/// Two-sided p-value for a Student's t statistic: `2 · P(T ≤ −|t|)`.
///
/// Matches the p-value R's `cor.test(method = "pearson")` and `t.test` report.
///
/// - Parameters:
///   - t: The observed t statistic.
///   - degreesOfFreedom: `df > 0`.
/// - Returns: The two-sided p-value in `[0, 1]`, or `.nan` if `degreesOfFreedom` is not positive.
public func studentTTwoSidedPValue(_ t: Double, degreesOfFreedom: Double) -> Double {
    guard degreesOfFreedom > 0 else { return .nan }
    return min(1.0, 2.0 * studentTCDF(-abs(t), degreesOfFreedom: degreesOfFreedom))
}

/// The Pearson product-moment correlation coefficient between two equal-length
/// vectors.
///
/// - Parameters:
///   - x: The first variable.
///   - y: The second variable, the same length as `x`.
/// - Returns: `r ∈ [-1, 1]`, or `.nan` if the vectors differ in length, have
///   fewer than two elements, or either has zero variance.
public func pearsonCorrelation(_ x: Vector, _ y: Vector) -> Double {
    guard x.count == y.count, x.count > 1 else { return .nan }

    let n = Double(x.count)
    let meanX = x.reduce(0, +) / n
    let meanY = y.reduce(0, +) / n

    var sxy = 0.0
    var sxx = 0.0
    var syy = 0.0
    for i in x.indices {
        let dx = x[i] - meanX
        let dy = y[i] - meanY
        sxy += dx * dy
        sxx += dx * dx
        syy += dy * dy
    }

    let denominator = (sxx * syy).squareRoot()
    guard denominator > 0 else { return .nan }
    return sxy / denominator
}
