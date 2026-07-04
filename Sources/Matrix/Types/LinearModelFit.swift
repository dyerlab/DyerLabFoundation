//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  LinearModelFit.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 7/4/26.
//

import Foundation

/// The result of fitting a general linear model `Y = Xβ + ε` via
/// ``linearModelFit(designMatrix:response:)``.
///
/// The same breakdown covers both simple linear regression (a continuous
/// column in the design matrix) and one-way analysis of variance (a
/// one-hot-coded design matrix from `Matrix.DesignMatrix(strata:)`), since
/// both designs contain the constant vector in their column space.
public struct LinearModelFit: Sendable {

    /// The fitted coefficients, β = (X'X)⁻¹X'Y.
    public let coefficients: Vector

    /// The fitted (predicted) response values, Xβ.
    public let fitted: Vector

    /// The residuals, Y - Xβ.
    public let residuals: Vector

    /// Degrees of freedom attributed to the model (number of design columns minus one).
    public let dfModel: Int

    /// Degrees of freedom attributed to the residuals (observations minus design columns).
    public let dfResidual: Int

    /// Total degrees of freedom (observations minus one).
    public let dfTotal: Int

    /// Sum of squares explained by the model.
    public let ssModel: Double

    /// Sum of squares left unexplained by the model.
    public let ssResidual: Double

    /// Total sum of squares around the response mean.
    public let ssTotal: Double

    /// Mean square for the model: ssModel / dfModel.
    public var msModel: Double { ssModel / Double(dfModel) }

    /// Mean square for the residuals: ssResidual / dfResidual.
    public var msResidual: Double { ssResidual / Double(dfResidual) }

    /// The F-statistic: msModel / msResidual.
    public var fStatistic: Double { msModel / msResidual }

    /// The coefficient of determination: ssModel / ssTotal.
    ///
    /// `.nan` when `ssTotal` is zero (a constant response) rather than
    /// dividing out to a stray `+/-infinity` from floating-point noise in
    /// `ssModel`.
    public var r2: Double { ssTotal > 0 ? ssModel / ssTotal : Double.nan }

    public init(coefficients: Vector, fitted: Vector, residuals: Vector,
                dfModel: Int, dfResidual: Int, dfTotal: Int,
                ssModel: Double, ssResidual: Double, ssTotal: Double) {
        self.coefficients = coefficients
        self.fitted = fitted
        self.residuals = residuals
        self.dfModel = dfModel
        self.dfResidual = dfResidual
        self.dfTotal = dfTotal
        self.ssModel = ssModel
        self.ssResidual = ssResidual
        self.ssTotal = ssTotal
    }
}
