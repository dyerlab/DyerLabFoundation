//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//
//  Created by Rodney Dyer on 4/23/26.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import SwiftUI

// MARK: - MatrixView

/// A scrollable, fully editable K×K matrix grid.
///
/// Composes `MatrixHeaderRow` and `MatrixDataRow` reusable components.
/// When `adjustDiagonalForRowStochastic` is `true`, editing any off-diagonal cell
/// automatically recomputes the diagonal so that each row sums to 1.0 — keeping
/// the matrix row-stochastic without a separate "Normalise" button.
///
/// ## Usage
///
/// ```swift
/// @State var values: [[Double]] = [[0.9, 0.1], [0.1, 0.9]]
/// let names = ["Pop1", "Pop2"]
///
/// MatrixView(values: $values, rowNames: names, colNames: names)
/// ```
public struct MatrixView: View {

    // MARK: - Layout constants

    /// Shared layout metrics used by `MatrixCell`, `MatrixHeaderRow`, and `MatrixDataRow`.
    public struct Constants {
        /// Width of a single data cell (points).
        public static let cellWidth: CGFloat    = 80
        /// Width of the leading row-name column (points).
        public static let headerWidth: CGFloat  = 72
        /// Width of the trailing row-sum column (points).
        public static let sumWidth: CGFloat     = 64
        /// Height of every row, including the header (points).
        public static let rowHeight: CGFloat    = 30
    }

    // MARK: - Properties

    /// The K×K matrix values stored row-major.
    @Binding public var values: [[Double]]

    /// Labels for each row.  Count must equal `values.count`.
    public let rowNames: [String]

    /// Labels for each column.  Count must equal `values[0].count`.
    public let colNames: [String]

    /// When `true`, editing any off-diagonal cell automatically recomputes the diagonal
    /// so that the row sums to 1.0.
    public var adjustDiagonalForRowStochastic: Bool

    // MARK: - Init

    /// Creates a `MatrixView`.
    ///
    /// - Parameters:
    ///   - values: Binding to the row-major `[[Double]]` values.
    ///   - rowNames: Labels for each row.
    ///   - colNames: Labels for each column.
    ///   - adjustDiagonalForRowStochastic: Whether to auto-compute the diagonal on each edit.
    public init(
        values: Binding<[[Double]]>,
        rowNames: [String],
        colNames: [String],
        adjustDiagonalForRowStochastic: Bool = true
    ) {
        self._values = values
        self.rowNames = rowNames
        self.colNames = colNames
        self.adjustDiagonalForRowStochastic = adjustDiagonalForRowStochastic
    }

    // MARK: - Body

    public var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                MatrixHeaderRow(colNames: colNames)
                ForEach(0..<values.count, id: \.self) { row in
                    MatrixDataRow(
                        row: row,
                        values: $values,
                        rowName: row < rowNames.count ? rowNames[row] : "\(row)",
                        adjustDiagonalForRowStochastic: adjustDiagonalForRowStochastic
                    )
                }
            }
        }
    }

}

// MARK: - Previews

private func steppingStoneValues(k: Int, m: Double) -> [[Double]] {
    var v = Array(repeating: Array(repeating: 0.0, count: k), count: k)
    for i in 0..<k {
        if i > 0     { v[i][i - 1] = m }
        if i < k - 1 { v[i][i + 1] = m }
        v[i][i] = 1.0 - v[i].reduce(0, +)
    }
    return v
}
#if !SPM_BUILD

#Preview("3-population stepping stone") {
    @Previewable @State var values = steppingStoneValues(k: 3, m: 0.05)
    let names = ["Pop1", "Pop2", "Pop3"]
    return MatrixView(values: $values, rowNames: names, colNames: names)
        .padding()
        .frame(minWidth: 400)
}

#Preview("5-population island model") {
    @Previewable @State var values: [[Double]] = {
        let k = 5
        let m = 0.02
        var v = Array(repeating: Array(repeating: 0.0, count: k), count: k)
        for i in 0..<k {
            for j in 0..<k where i != j { v[i][j] = m / Double(k - 1) }
            v[i][i] = 1.0 - m
        }
        return v
    }()
    let names = (1...5).map { "Pop\($0)" }
    return MatrixView(values: $values, rowNames: names, colNames: names)
        .padding()
        .frame(minWidth: 500)
}
#endif
