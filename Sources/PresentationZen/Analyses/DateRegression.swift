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

/// Computes a linear regression on date-based ``DataPoint`` data.
///
/// Groups points by date, averages `yValue` per group, then fits a
/// linear model on days-since-first-date vs yValue.
///
/// - Parameter data: An array of ``DataPoint`` where `date` is non-nil.
/// - Returns: A ``RegressionResult`` with slope (per day), intercept, R², and fitted points, or `nil` if insufficient data.
public func dateRegression(data: [DataPoint]) -> RegressionResult? {
    let dated = data.filter { $0.date != nil }
    let grouped = Dictionary(grouping: dated) { $0.date! }
    let vals = grouped.map { (date, group) in
        DataPoint(time: date, value: group.map(\.yValue).reduce(0, +) / Double(group.count))
    }.sorted()

    guard vals.count > 1 else { return nil }

    let firstDate = vals.compactMap(\.date).min()!
    let x = vals.map { $0.date!.timeIntervalSince(firstDate) / 86400.0 }
    let y = vals.map(\.yValue)

    let n = Double(x.count)
    let meanX = x.reduce(0, +) / n
    let meanY = y.reduce(0, +) / n
    let sXY = zip(x, y).map { ($0 - meanX) * ($1 - meanY) }.reduce(0, +)
    let sXX = x.map { pow($0 - meanX, 2) }.reduce(0, +)

    guard sXX > 0 else { return nil }

    let slope = sXY / sXX
    let intercept = meanY - slope * meanX

    let fitted = zip(x, vals).map { (xi, dv) in
        DataPoint(time: dv.date!, value: slope * xi + intercept)
    }

    let ssTot = y.map { pow($0 - meanY, 2) }.reduce(0, +)
    let ssRes = zip(y, fitted.map(\.yValue)).map { pow($0 - $1, 2) }.reduce(0, +)
    let r2 = ssTot > 0 ? 1 - ssRes / ssTot : Double.nan

    return RegressionResult(slope: slope, intercept: intercept, r2: r2, fitted: fitted)
}
