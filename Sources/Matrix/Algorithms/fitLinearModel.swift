//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  fitLinearModel.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 7/4/26.
//

import Foundation

/// Fits a general linear model `Y = Xβ + ε` via `β = (X'X)⁻¹X'Y`.
///
/// This is the shared numerical core behind both simple linear regression (a
/// design matrix with a continuous predictor column) and one-way analysis of
/// variance (a one-hot design matrix from `Matrix.DesignMatrix(strata:)`).
/// Both cases share the same degrees-of-freedom bookkeeping because the
/// constant vector lies in the column space of either design.
///
/// - Parameters:
///   - X: The N×p design matrix (N observations, p parameters).
///   - y: The response vector of length N.
/// - Returns: A ``LinearModelFit``, or `nil` if the dimensions don't match,
///   there are too few observations to estimate the model (`N < p`), or
///   `X'X` is singular. An exact fit (`N == p`) is allowed — the coefficients
///   and fitted values are still well-defined, but `dfResidual` is zero, so
///   `msResidual`/`fStatistic` come out `Double.nan` (0/0) rather than the
///   whole call failing.
///
/// ## Example
/// ```swift
/// // Simple regression: intercept + one predictor.
/// let X = Matrix(days.count, 2, days.flatMap { [1.0, $0] })
/// let fit = linearModelFit(designMatrix: X, response: y)
/// ```
public func linearModelFit(designMatrix X: Matrix, response y: Vector) -> LinearModelFit? {

    guard X.rows == y.count, X.rows >= X.cols, X.cols > 0 else { return nil }

    // Treat y as an N×1 matrix throughout so every step goes through the
    // general Matrix .* Matrix multiply — the Matrix .* Vector operator only
    // produces correct results for square matrices, which the design matrix
    // is not in general.
    let Y = Matrix(y.count, 1, y)
    let XtX = X.transpose .* X
    let XtXInverse = GeneralizedInverse(XtX)

    // GeneralizedInverse signals failure (non-square input or a singular
    // matrix) by returning an empty 0x0 matrix.
    guard XtXInverse.rows == X.cols else { return nil }

    let coefficients = (XtXInverse .* X.transpose .* Y).getCol(c: 0)
    let fitted = (X .* Matrix(X.cols, 1, coefficients)).getCol(c: 0)
    let residuals = y - fitted

    let meanY = y.mean
    let ssTotal = y.map { pow($0 - meanY, 2) }.sum
    let ssResidual = residuals.map { $0 * $0 }.sum
    let ssModel = ssTotal - ssResidual

    return LinearModelFit(
        coefficients: coefficients,
        fitted: fitted,
        residuals: residuals,
        dfModel: X.cols - 1,
        dfResidual: X.rows - X.cols,
        dfTotal: X.rows - 1,
        ssModel: ssModel,
        ssResidual: ssResidual,
        ssTotal: ssTotal
    )
}
