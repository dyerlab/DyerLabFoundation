//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RegressionLine.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// A straight line `y = intercept + slope · x`.
public struct RegressionLine: Sendable, Equatable, Hashable {

    /// The value at `x = 0`.
    public let intercept: Double

    /// The change in `y` per unit `x`.
    public let slope: Double

    /// Creates a line.
    ///
    /// - Parameters:
    ///   - intercept: The value at `x = 0`.
    ///   - slope: The change in `y` per unit `x`.
    public init(intercept: Double, slope: Double) {
        self.intercept = intercept
        self.slope = slope
    }

    /// The least-squares line of `y` on `x` (R's `coef(lm(y ~ x))`).
    ///
    /// - Parameters:
    ///   - x: The predictor values.
    ///   - y: The response values, the same length as `x`.
    /// - Returns: The fitted line, or `nil` if there are fewer than two values,
    ///   the lengths differ, or `x` is constant.
    public init?(leastSquaresOf y: [Double], on x: [Double]) {
        guard x.count == y.count, x.count >= 2 else { return nil }
        let mx = x.reduce(0, +) / Double(x.count)
        let my = y.reduce(0, +) / Double(y.count)
        let sxy = zip(x, y).reduce(0.0) { $0 + ($1.0 - mx) * ($1.1 - my) }
        let sxx = x.reduce(0.0) { $0 + ($1 - mx) * ($1 - mx) }
        guard sxx > 0 else { return nil }
        self.init(intercept: my - sxy / sxx * mx, slope: sxy / sxx)
    }

    /// The line's value at `x`.
    ///
    /// - Parameter x: The predictor value.
    /// - Returns: `intercept + slope · x`.
    public func value(at x: Double) -> Double {
        intercept + slope * x
    }
}
