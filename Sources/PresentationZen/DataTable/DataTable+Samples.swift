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
//  DataTable+Samples.swift
//
//  Deterministic sample tables used by chart previews and tests. They replace
//  the legacy `DataPoint.defaultDataPoints` fixtures.
//

import Foundation

public extension DataTable {

    /// Quantitative x/y points with `group` and `label` columns available.
    /// Bound roles: `x`, `y`.
    static var sampleScatter: DataTable {
        DataTable(
            numbers: ["x": (0 ..< 10).map(Double.init),
                      "y": [12, 40, 18, 55, 30, 62, 25, 48, 33, 70]],
            strings: ["group": (0 ..< 10).map { "Group \($0 % 3 + 1)" },
                      "label": (0 ..< 10).map { "P\($0 + 1)" }],
            roles: [.x: "x", .y: "y"]
        )
    }

    /// Categorical bars with a `group` column available.
    /// Bound roles: `x` (category), `y`.
    static var sampleBars: DataTable {
        DataTable(
            numbers: ["value": [12, 40, 18, 55]],
            strings: ["category": ["Alpha", "Beta", "Gamma", "Delta"],
                      "group": ["A", "B", "A", "B"]],
            roles: [.x: "category", .y: "value"]
        )
    }

    /// A single numeric column of raw values, suitable for `.histogram()` /
    /// `.frequency()`. Bound role: `y`.
    static var sampleValues: DataTable {
        DataTable(numbers: ["value": [1, 2, 2, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 6, 6, 7]],
                  roles: [.y: "value"])
    }

    /// A temporal series with a `series` column available.
    /// Bound roles: `x` (date), `y`.
    static var sampleTemporal: DataTable {
        let day = 86_400.0
        let dates = (0 ..< 8).map { Date(timeIntervalSinceNow: -Double(7 - $0) * 30 * day) }
        return DataTable(
            numbers: ["value": [10, 14, 9, 20, 18, 25, 22, 30]],
            dates: ["date": dates],
            strings: ["series": Array(repeating: "Series A", count: 8)],
            roles: [.x: "date", .y: "value"]
        )
    }
}
