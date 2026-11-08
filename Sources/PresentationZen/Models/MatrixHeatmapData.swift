//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MatrixHeatmapData.swift
//  PresentationZen
//
//  The numbers a matrix heatmap draws, in a `Sendable` form that can be made
//  off the main actor: the row and column names, the values row by row, an
//  optional group for each row (such as an individual's population, so the
//  heatmap can mark where groups change), and the units. `Matrix` itself is a
//  class and can't cross actors.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix

/// A matrix's names, values and groups, ready for a heatmap.
public struct MatrixHeatmapData: Sendable, Equatable {

    /// One run of consecutive rows in the same group.
    public struct GroupRun: Sendable, Equatable {
        /// The group's name.
        public let name: String
        /// The rows it covers.
        public let rows: Range<Int>
    }

    /// The row names.
    public let rowNames: [String]
    /// The column names.
    public let columnNames: [String]
    /// The values, row by row.
    public let values: [Double]
    /// Each row's group, or `nil`.
    public let groups: [String]?
    /// The values' units, such as `km`.
    public let units: String?

    // MARK: - Initialization

    /// Creates heatmap data.
    ///
    /// - Parameters:
    ///   - rowNames: The row names.
    ///   - columnNames: The column names.
    ///   - values: The values, row by row; there must be `rowNames.count × columnNames.count` of them.
    ///   - groups: Each row's group, or `nil`.
    ///   - units: The values' units.
    public init(rowNames: [String], columnNames: [String], values: [Double], groups: [String]? = nil,
                units: String? = nil) {
        precondition(values.count == rowNames.count * columnNames.count, "one value per cell")
        self.rowNames = rowNames
        self.columnNames = columnNames
        self.values = values
        self.groups = groups?.count == rowNames.count ? groups : nil
        self.units = units
    }

    /// The heatmap data of a matrix.
    ///
    /// - Parameters:
    ///   - matrix: The matrix.
    ///   - groups: Each row's group, or `nil`.
    ///   - units: The values' units.
    public init(_ matrix: Matrix, groups: [String]? = nil, units: String? = nil) {
        let rowNames = matrix.rowNames.count == matrix.rows ? matrix.rowNames : (1...max(matrix.rows, 1)).map(String.init)
        let columnNames = matrix.colNames.count == matrix.cols ? matrix.colNames
            : (1...max(matrix.cols, 1)).map(String.init)
        self.init(rowNames: Array(rowNames.prefix(matrix.rows)), columnNames: Array(columnNames.prefix(matrix.cols)),
                  values: matrix.nestedArray.flatMap { $0 }, groups: groups, units: units)
    }

    // MARK: - Contents

    /// Whether the matrix is square with the same names on both sides, as a distance matrix is.
    public var isSymmetricInLayout: Bool {
        rowNames == columnNames
    }

    /// The values the histogram counts: each pair once for a square matrix (its upper triangle), every finite
    /// value otherwise.
    public var pairValues: [Double] {
        let n = rowNames.count
        guard isSymmetricInLayout else { return values.filter(\.isFinite) }
        var pairs: [Double] = []
        pairs.reserveCapacity(n * (n - 1) / 2)
        for i in 0..<n {
            for j in (i + 1)..<n where values[i * n + j].isFinite { pairs.append(values[i * n + j]) }
        }
        return pairs
    }

    /// The smallest and largest finite values, or `nil` when there are none.
    public var valueRange: ClosedRange<Double>? {
        let finite = values.filter(\.isFinite)
        guard let low = finite.min(), let high = finite.max() else { return nil }
        return low...high
    }

    /// The runs of consecutive rows in the same group, in row order.
    public var groupRuns: [GroupRun] {
        guard let groups, !groups.isEmpty else { return [] }
        var runs: [GroupRun] = []
        var start = 0
        for row in 1...groups.count where row == groups.count || groups[row] != groups[start] {
            runs.append(GroupRun(name: groups[start], rows: start..<row))
            start = row
        }
        return runs
    }

    /// The value at a row and column.
    ///
    /// - Parameters:
    ///   - row: The row.
    ///   - column: The column.
    /// - Returns: The value.
    public func value(row: Int, column: Int) -> Double {
        values[row * columnNames.count + column]
    }
}
