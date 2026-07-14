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
//  DataTable+Transforms.swift
//
//  Data shaping expressed as DataTable -> DataTable operations, so the charts
//  stay dumb renderers. Numeric binning delegates to `Vector` in the Matrix
//  target; the table layer only handles role plumbing.
//

import Foundation
import Matrix

/// A per-category median/standard-deviation summary, for box plots.
///
/// Replaces the legacy `BoxPlotPoint`.
public struct BoxSummary: Identifiable, Hashable, Sendable {
    public var id: String { category }
    public let category: String
    public let median: Double
    public let sd: Double

    /// Creates a box summary.
    ///
    /// - Parameters:
    ///   - category: The category name; also this instance's `id`.
    ///   - median: The category's median value.
    ///   - sd: The category's standard deviation.
    public init(category: String, median: Double, sd: Double) {
        self.category = category
        self.median = median
        self.sd = sd
    }
}

public extension DataTable {

    /// Bins a numeric column into a histogram table.
    ///
    /// - Parameters:
    ///   - column: The column to bin; defaults to the column bound to `y`.
    ///   - bins: The number of equal-width bins.
    /// - Returns: A table with `x` = bin center and `y` = count.
    func histogram(of column: String? = nil, bins: Int = 10) -> DataTable {
        guard let name = column ?? roles[.y] else { return Self.emptyXY() }
        let histogram = self.column(name).histogram(bins: bins)
        return DataTable(numbers: ["bin": histogram.map(\.center),
                                   "count": histogram.map { Double($0.count) }],
                         roles: [.x: "bin", .y: "count"])
    }

    /// Counts a numeric column into integer buckets.
    ///
    /// - Parameters:
    ///   - column: The column to count; defaults to the column bound to `y`.
    ///   - range: The inclusive integer bucket range (e.g. `1...5` for Likert).
    /// - Returns: A table with categorical `x` = bucket label and `y` = count.
    func frequency(of column: String? = nil, range: ClosedRange<Int>) -> DataTable {
        guard let name = column ?? roles[.y] else { return Self.emptyXY() }
        let counts = self.column(name).frequency(range: range)
        return DataTable(numbers: ["count": counts.map(Double.init)],
                         strings: ["bucket": range.map { String($0) }],
                         roles: [.x: "bucket", .y: "count"])
    }

    /// Sums a numeric column within each unit of a date column's calendar
    /// component (e.g. by `.year`).
    ///
    /// - Parameters:
    ///   - component: The calendar component to collapse on.
    ///   - column: The column to sum; defaults to the column bound to `y`.
    ///   - dateColumn: The date column; defaults to the `x` role when it is a
    ///     date, otherwise the first date column found.
    /// - Returns: A table with quantitative `x` = the integer unit value and
    ///   `y` = the per-unit sum, sorted ascending by unit.
    func collapsed(by component: Calendar.Component,
                   summing column: String? = nil,
                   dateColumn: String? = nil) -> DataTable {
        let valueName = column ?? roles[.y]
        let dateName = dateColumn
            ?? (roles[.x].flatMap { kind(of: $0) == .date ? $0 : nil })
            ?? columnNames.first { kind(of: $0) == .date }

        guard let valueName, let dateName else { return Self.emptyXY() }

        let dates = Array(frame[dateName, Date.self])
        let values = numericColumn(valueName)
        let calendar = Calendar.current

        var sums = [Int: Double]()
        for i in 0 ..< Swift.min(dates.count, values.count) {
            guard let date = dates[i], let value = values[i], value.isFinite else { continue }
            let unit = calendar.component(component, from: date)
            sums[unit, default: 0] += value
        }

        let units = sums.keys.sorted()
        return DataTable(numbers: ["period": units.map(Double.init),
                                   "total": units.map { sums[$0] ?? 0 }],
                         roles: [.x: "period", .y: "total"])
    }

    /// Builds the two endpoints of a trendline across the `x` column's range.
    ///
    /// - Parameters:
    ///   - intercept: The line's value at `x = 0`.
    ///   - slope: The line's slope.
    /// - Returns: A two-row table with `x`/`y` roles set, spanning the minimum
    ///   to maximum x of the bound `x` column.
    func trendline(intercept: Double, slope: Double) -> DataTable {
        guard let xName = roles[.x] else { return Self.emptyXY() }
        let xs = self.column(xName)
        guard let lo = xs.min(), let hi = xs.max() else { return Self.emptyXY() }
        return DataTable(numbers: ["x": [lo, hi],
                                   "y": [lo * slope + intercept, hi * slope + intercept]],
                         roles: [.x: "x", .y: "y"])
    }

    /// Summarises the `y` column by the categorical `x` column.
    ///
    /// - Returns: One ``BoxSummary`` per distinct x category, in category
    ///   order, each carrying the median and standard deviation of its y
    ///   values.
    func boxSummary() -> [BoxSummary] {
        guard let xName = roles[.x], let yName = roles[.y] else { return [] }
        let categories = stringColumn(xName)
        let values = numericColumn(yName)

        var grouped = [String: [Double]]()
        var order = [String]()
        for i in 0 ..< Swift.min(categories.count, values.count) {
            guard let category = categories[i], let value = values[i], value.isFinite else { continue }
            if grouped[category] == nil { order.append(category) }
            grouped[category, default: []].append(value)
        }

        return order.map { category in
            let ys = grouped[category] ?? []
            return BoxSummary(category: category, median: ys.median(), sd: ys.sd())
        }
    }
}

private extension DataTable {
    /// An empty table that still carries `x`/`y` roles, so downstream charts
    /// resolve to zero rows instead of crashing on a missing role.
    static func emptyXY() -> DataTable {
        DataTable(numbers: ["x": [], "y": []], roles: [.x: "x", .y: "y"])
    }
}
