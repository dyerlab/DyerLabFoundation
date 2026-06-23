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
//  DataTable.swift
//
//  A typed, columnar container for plottable data built on Apple's
//  `TabularData.DataFrame`, plus a mapping of plot roles to column names.
//  Charts consume a `DataTable`; the numeric core (`Matrix`/`Vector`)
//  round-trips through it.
//

import Foundation
import TabularData

/// A role-mapped, typed table of plottable data.
///
/// A `DataTable` pairs a `TabularData.DataFrame` with a mapping of
/// ``DataColumnRole`` to column name. Assign roles fluently
/// (`table.x("lon").y("count").series("site")`) and the charts read columns
/// by role. Transformations (binning, frequency, time-collapse, trendlines)
/// are `DataTable -> DataTable` operations so the charts stay dumb.
///
/// - Note: `DataFrame` is not `Sendable`, so `DataTable` is a plain
///   value-semantic struct — neither `Sendable` nor actor-isolated. Use it
///   within a single actor (e.g. a `@MainActor` view). To cross actor
///   boundaries, pass the `Sendable` projections (``PlotRow``, ``PlotValue``)
///   or extract `Vector`/`Matrix` data first.
public struct DataTable {

    /// The backing data frame.
    public private(set) var frame: DataFrame

    /// The mapping of plot roles to column names.
    public internal(set) var roles: [DataColumnRole: String]

    /// Creates a table from a data frame and an optional role mapping.
    public init(frame: DataFrame, roles: [DataColumnRole: String] = [:]) {
        self.frame = frame
        self.roles = roles
    }

    /// Creates a table from typed column dictionaries.
    ///
    /// Columns are appended in a stable order: numbers, then dates, then
    /// strings, each alphabetised by name for determinism.
    public init(numbers: [String: [Double]],
                dates:   [String: [Date]]   = [:],
                strings: [String: [String]] = [:],
                roles:   [DataColumnRole: String] = [:]) {
        var df = DataFrame()
        for name in numbers.keys.sorted() {
            df.append(column: Column(name: name, contents: numbers[name]!))
        }
        for name in dates.keys.sorted() {
            df.append(column: Column(name: name, contents: dates[name]!))
        }
        for name in strings.keys.sorted() {
            df.append(column: Column(name: name, contents: strings[name]!))
        }
        self.init(frame: df, roles: roles)
    }

    /// The number of rows in the table.
    public var rowCount: Int { frame.rows.count }

    /// The names of every column, in column order.
    public var columnNames: [String] { frame.columns.map(\.name) }

    /// The value kind of a named column, or `nil` if absent or unsupported.
    public func kind(of columnName: String) -> ColumnKind? {
        guard let column = frame.columns.first(where: { $0.name == columnName }) else { return nil }
        let type = column.wrappedElementType
        if type == Double.self || type == Int.self || type == Float.self { return .number }
        if type == Date.self { return .date }
        if type == String.self { return .category }
        return nil
    }
}

// MARK: - Internal typed column readers

extension DataTable {

    /// Reads a numeric column (Double/Int/Float) as `[Double?]`, preserving
    /// row order and `nil` (missing) entries.
    func numericColumn(_ name: String) -> [Double?] {
        guard let column = frame.columns.first(where: { $0.name == name }) else { return [] }
        let type = column.wrappedElementType
        if type == Double.self { return Array(frame[name, Double.self]) }
        if type == Int.self    { return frame[name, Int.self].map { $0.map(Double.init) } }
        if type == Float.self  { return frame[name, Float.self].map { $0.map(Double.init) } }
        return []
    }

    /// Reads any column as `[String?]`, converting non-string kinds via their
    /// natural description. Used for the `series` and `label` roles.
    func stringColumn(_ name: String) -> [String?] {
        guard let column = frame.columns.first(where: { $0.name == name }) else { return [] }
        let type = column.wrappedElementType
        if type == String.self { return Array(frame[name, String.self]) }
        if type == Double.self { return frame[name, Double.self].map { $0.map { String($0) } } }
        if type == Int.self    { return frame[name, Int.self].map { $0.map { String($0) } } }
        if type == Float.self  { return frame[name, Float.self].map { $0.map { String($0) } } }
        if type == Date.self   { return frame[name, Date.self].map { $0.map { $0.description } } }
        return Array(repeating: nil, count: rowCount)
    }

    /// Reads a column as `[PlotValue?]` according to its kind.
    func plotValues(_ name: String) -> [PlotValue?] {
        switch kind(of: name) {
        case .number:   return numericColumn(name).map { $0.map(PlotValue.number) }
        case .date:     return Array(frame[name, Date.self]).map { $0.map(PlotValue.date) }
        case .category: return Array(frame[name, String.self]).map { $0.map(PlotValue.category) }
        case .none:     return []
        }
    }
}
