//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  DateRegression.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026-02-16.
//

import Foundation
import Matrix

/// Computes a linear regression over a table's temporal data.
///
/// Groups rows by date, averages the `y` value per group, then fits a linear
/// model (intercept + days-since-first-date) via ``linearModelFit(designMatrix:response:)``,
/// the same general-linear-model core used for `anovaTable(_:)`.
///
/// - Parameter table: A ``DataTable`` whose `x` role is a date column and
///   whose `y` role is the value column.
/// - Returns: A ``RegressionResult`` with slope (per day), intercept, R², and
///   fitted ``PlotRow`` values (date x), or `nil` if there is insufficient
///   data or no date/value roles are bound.
public func dateRegression(_ table: DataTable) -> RegressionResult? {
    guard let xName = table.column(for: .x), table.kind(of: xName) == .date,
          table.column(for: .y) != nil else { return nil }

    // Average y within each distinct date, then sort chronologically.
    let dated = table.plotRows.compactMap { row -> (Date, Double)? in
        guard let date = row.x.dateValue else { return nil }
        return (date, row.y)
    }
    let grouped = Dictionary(grouping: dated, by: { $0.0 })
    let vals = grouped
        .map { (date, group) in (date, group.map(\.1).reduce(0, +) / Double(group.count)) }
        .sorted { $0.0 < $1.0 }

    guard vals.count > 1 else { return nil }

    let firstDate = vals[0].0
    let days = vals.map { $0.0.timeIntervalSince(firstDate) / 86_400.0 }
    let y = vals.map(\.1)

    let designMatrix = Matrix(days.count, 2, days.flatMap { [1.0, $0] })
    guard let fit = linearModelFit(designMatrix: designMatrix, response: y) else { return nil }

    let fitted = vals.enumerated().map { index, datedValue in
        PlotRow(id: index, x: .date(datedValue.0), y: fit.fitted[index])
    }

    return RegressionResult(slope: fit.coefficients[1], intercept: fit.coefficients[0],
                             r2: fit.r2, fitted: fitted, fit: fit)
}
