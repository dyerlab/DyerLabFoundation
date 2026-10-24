//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DataTable+Matrix.swift
//  PresentationZen
//
//  The bridge between the numeric core (`Matrix`/`Vector`) and the table.
//  This is what closes the loop: CSV -> DataTable -> Matrix -> PCA/t-SNE ->
//  DataTable -> chart.
//
//  Created by Rodney Dyer on 2026.06.23.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix
import TabularData

public extension DataTable {

    /// Builds a table from a matrix.
    ///
    /// Each matrix column becomes a numeric column named by its
    /// `colNames` entry; the `rowNames` become a string label column bound to
    /// the ``DataColumnRole/label`` role.
    ///
    /// - Parameters:
    ///   - matrix: The source matrix.
    ///   - labelColumn: The name of the generated row-label column.
    init(matrix: Matrix, labelColumn: String = "Label") {
        var df = DataFrame()
        df.append(column: Column(name: labelColumn, contents: matrix.rowNames))
        for j in 0 ..< matrix.cols {
            let values: [Double] = (0 ..< matrix.rows).map { matrix[$0, j] }
            let name = j < matrix.colNames.count ? matrix.colNames[j] : "col\(j)"
            df.append(column: Column(name: name, contents: values))
        }
        self.init(frame: df, roles: [.label: labelColumn])
    }

    /// Builds a single-column table from a vector, bound to the `y` role.
    ///
    /// - Parameters:
    ///   - vector: The column's values.
    ///   - name: The column's name (default `"value"`).
    init(vector: Vector, name: String = "value") {
        var df = DataFrame()
        df.append(column: Column(name: name, contents: vector))
        self.init(frame: df, roles: [.y: name])
    }

    /// Extracts a numeric column as a `Vector`, dropping missing values.
    ///
    /// Use for statistics and binning where only the valid observations
    /// matter. Returns an empty vector for non-numeric or absent columns.
    ///
    /// - Parameter name: The column to extract.
    /// - Returns: The column's non-missing values, in row order.
    func column(_ name: String) -> Vector {
        numericColumn(name).compactMap { $0 }
    }

    /// Projects numeric columns into a row-major `Matrix`.
    ///
    /// Missing values are zero-filled to keep the result rectangular. When a
    /// ``DataColumnRole/label`` role is bound, its values become the matrix
    /// `rowNames`.
    ///
    /// - Parameter columns: The columns to include, in order. When `nil`,
    ///   every numeric column is used (in column order).
    /// - Returns: A `rowCount × columns.count` matrix, or an empty `0 × 0` matrix if there are no rows or columns.
    func asMatrix(_ columns: [String]? = nil) -> Matrix {
        let names = columns ?? columnNames.filter { kind(of: $0) == .number }
        let rows = rowCount
        guard !names.isEmpty, rows > 0 else { return Matrix(0, 0) }

        // Read each column once; zero-fill nils so the buffer stays rectangular.
        let columnData: [[Double]] = names.map { name in
            numericColumn(name).map { $0 ?? 0 }
        }

        var flat = Vector()
        flat.reserveCapacity(rows * names.count)
        for r in 0 ..< rows {
            for c in 0 ..< names.count {
                flat.append(r < columnData[c].count ? columnData[c][r] : 0)
            }
        }

        let result = Matrix(rows, names.count, flat)
        result.colNames = names
        if let labelName = roles[.label] {
            let labels = stringColumn(labelName).map { $0 ?? "" }
            if labels.count == rows { result.rowNames = labels }
        }
        return result
    }
}
