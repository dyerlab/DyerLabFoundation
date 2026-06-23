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

/// Computes a linear regression over a table's temporal data.
///
/// Groups rows by date, averages the `y` value per group, then fits a linear
/// model on days-since-first-date vs value.
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
    let x = vals.map { $0.0.timeIntervalSince(firstDate) / 86_400.0 }
    let y = vals.map(\.1)

    let n = Double(x.count)
    let meanX = x.reduce(0, +) / n
    let meanY = y.reduce(0, +) / n
    let sXY = zip(x, y).map { ($0 - meanX) * ($1 - meanY) }.reduce(0, +)
    let sXX = x.map { pow($0 - meanX, 2) }.reduce(0, +)

    guard sXX > 0 else { return nil }

    let slope = sXY / sXX
    let intercept = meanY - slope * meanX

    let fitted = vals.enumerated().map { index, datedValue in
        PlotRow(id: index, x: .date(datedValue.0), y: slope * x[index] + intercept)
    }

    let ssTot = y.map { pow($0 - meanY, 2) }.reduce(0, +)
    let ssRes = zip(y, fitted.map(\.y)).map { pow($0 - $1, 2) }.reduce(0, +)
    let r2 = ssTot > 0 ? 1 - ssRes / ssTot : Double.nan

    return RegressionResult(slope: slope, intercept: intercept, r2: r2, fitted: fitted)
}
