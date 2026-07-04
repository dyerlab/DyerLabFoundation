//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  anovaTable.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 7/4/26.
//

import Foundation
import Matrix

/// Formats a fitted general linear model's degrees-of-freedom, sum-of-squares,
/// mean-square, and F-statistic breakdown as a classic ANOVA source table.
///
/// - Parameter fit: Any fitted general linear model — simple regression and
///   one-way analysis of variance both produce a ``LinearModelFit``.
/// - Returns: A three-row `DataTable` (`Model`, `Residual`, `Total`) with
///   `source`/`df`/`ss`/`ms`/`f` columns. `ms`/`f` are `Double.nan` on the
///   `Total` row (and `f` on `Residual`), matching a standard ANOVA table.
public func anovaTable(_ fit: LinearModelFit) -> DataTable {
    DataTable(
        numbers: [
            "df": [Double(fit.dfModel), Double(fit.dfResidual), Double(fit.dfTotal)],
            "ss": [fit.ssModel, fit.ssResidual, fit.ssTotal],
            "ms": [fit.msModel, fit.msResidual, Double.nan],
            "f": [fit.fStatistic, Double.nan, Double.nan],
        ],
        strings: ["source": ["Model", "Residual", "Total"]]
    )
}

/// Formats a regression model's df/SS/MS/F breakdown.
///
/// - Parameter result: A ``RegressionResult`` produced by `dateRegression(_:)`.
/// - Returns: The ANOVA source table, or `nil` if `result` was built directly
///   rather than fit from data (so it carries no ``LinearModelFit``).
public func anovaTable(_ result: RegressionResult) -> DataTable? {
    result.fit.map(anovaTable)
}

/// Fits and formats a one-way analysis of variance directly from a table.
///
/// Reads the same `.x` (categorical group) / `.y` (numeric response) role
/// contract as `BoxPlot` — the two are natural companions, since a box plot
/// visualizes exactly what this tests. Builds the design matrix via
/// `Matrix.DesignMatrix(strata:)` and fits it with the same
/// `linearModelFit(designMatrix:response:)` core used by `dateRegression`.
///
/// - Parameter table: A ``DataTable`` whose `x` role is a categorical (group)
///   column and whose `y` role is the numeric response.
/// - Returns: The ANOVA source table, or `nil` if the roles aren't bound as
///   described, or there's too little data to fit the model.
public func anovaTable(_ table: DataTable) -> DataTable? {
    guard let xName = table.column(for: .x), table.kind(of: xName) == .category,
          let yName = table.column(for: .y) else { return nil }

    let categories = table.stringColumn(xName)
    let values = table.numericColumn(yName)

    var strata: [String] = []
    var response: Vector = []
    for i in 0 ..< min(categories.count, values.count) {
        guard let category = categories[i], let value = values[i], value.isFinite else { continue }
        strata.append(category)
        response.append(value)
    }

    guard let fit = linearModelFit(designMatrix: Matrix.DesignMatrix(strata: strata), response: response)
    else { return nil }
    return anovaTable(fit)
}

/// Formats a permutation test's degrees-of-freedom, sum-of-squares,
/// mean-square, and F-statistic breakdown, with an empirical p-value on the
/// `Model` row in place of an assumed F-distribution.
///
/// - Parameter result: A ``PermutationTestResult``.
/// - Returns: The ANOVA source table with an added `p` column (`Double.nan`
///   on the `Residual`/`Total` rows, matching how `ms`/`f` are already
///   padded there).
public func anovaTable(_ result: PermutationTestResult) -> DataTable {
    let fit = result.observed
    return DataTable(
        numbers: [
            "df": [Double(fit.dfModel), Double(fit.dfResidual), Double(fit.dfTotal)],
            "ss": [fit.ssModel, fit.ssResidual, fit.ssTotal],
            "ms": [fit.msModel, fit.msResidual, Double.nan],
            "f": [fit.fStatistic, Double.nan, Double.nan],
            "p": [result.pValue, Double.nan, Double.nan],
        ],
        strings: ["source": ["Model", "Residual", "Total"]]
    )
}

/// The null MSA (among-group variance component) distribution from a
/// permutation test, as a raw single-column `DataTable` ready for binning
/// and charting.
///
/// - Parameter result: A ``PermutationTestResult``.
/// - Returns: A `DataTable` with one `msA` column (one row per permutation)
///   and its `.y` role already bound, e.g.
///   `Histogram(nullDistributionTable(result).histogram(of: "msA", bins: 20))`.
public func nullDistributionTable(_ result: PermutationTestResult) -> DataTable {
    DataTable(numbers: ["msA": result.nullDistribution], roles: [.y: "msA"])
}
