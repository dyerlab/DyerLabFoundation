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

// MARK: - MatrixDataRow

/// One row in a `MatrixView`, comprising a row-name label, K `MatrixCell` views, and
/// a trailing row-sum indicator.
///
/// When `adjustDiagonalForRowStochastic` is `true`, editing any off-diagonal cell
/// automatically recomputes the diagonal entry so that the row sum equals 1.0:
///
/// ```
/// values[row][row] = max(0, 1.0 − Σ off-diagonal cells)
/// ```
///
/// The row is tinted red when its sum deviates from 1.0 by more than `Constants.sumTolerance`.
public struct MatrixDataRow: View {

    // MARK: - Constants

    public struct Constants {
        /// Tolerance for accepting a row sum as valid (equal to 1.0).
        public static let sumTolerance: Double    = 1e-9
        /// Text colour for a valid row sum.
        public static let validSumColor: Color    = .secondary
        /// Text colour for an invalid row sum.
        public static let invalidSumColor: Color  = .red
        /// Background tint applied to rows whose sum is outside tolerance.
        public static let invalidRowBackground: Color = Color.red.opacity(0.07)
    }

    // MARK: - Properties

    /// Index of this row in the K×K `values` array.
    public let row: Int

    /// The full K×K matrix values; this row mutates `values[row][*]`.
    @Binding public var values: [[Double]]

    /// Label displayed in the leading column.
    public let rowName: String

    /// When `true`, the diagonal cell is read-only and recomputed on every off-diagonal edit.
    public let adjustDiagonalForRowStochastic: Bool

    // MARK: - Computed helpers

    private var rowValues: [Double] {
        guard row < values.count else { return [] }
        return values[row]
    }

    private var rowSum: Double { rowValues.reduce(0, +) }

    private var isValid: Bool { abs(rowSum - 1.0) <= Constants.sumTolerance }

    /// Returns a `Binding<Double>` for `values[row][col]` that also keeps the diagonal
    /// in sync when `adjustDiagonalForRowStochastic` is active.
    private func binding(for col: Int) -> Binding<Double> {
        Binding(
            get: {
                guard row < values.count, col < values[row].count else { return 0 }
                return values[row][col]
            },
            set: { newValue in
                guard row < values.count, col < values[row].count else { return }
                values[row][col] = newValue
                guard adjustDiagonalForRowStochastic, col != row else { return }
                let offDiagonalSum = values[row].enumerated()
                    .filter { $0.offset != row }
                    .map(\.element)
                    .reduce(0, +)
                values[row][row] = max(0.0, 1.0 - offDiagonalSum)
            }
        )
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 0) {
            Text(rowName)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: MatrixView.Constants.headerWidth,
                       height: MatrixView.Constants.rowHeight)

            ForEach(0..<rowValues.count, id: \.self) { col in
                let isDiagonal = row == col
                MatrixCell(
                    value: binding(for: col),
                    isDiagonal: isDiagonal,
                    isReadOnly: isDiagonal && adjustDiagonalForRowStochastic
                )
            }

            Text(String(format: "%.\(MatrixCell.Constants.decimalPrecision)f", rowSum))
                .font(.caption.monospacedDigit())
                .foregroundStyle(isValid ? Constants.validSumColor : Constants.invalidSumColor)
                .frame(width: MatrixView.Constants.sumWidth,
                       height: MatrixView.Constants.rowHeight)
        }
        .background(isValid ? Color.clear : Constants.invalidRowBackground)
    }

}
#if !SPM_BUILD

// MARK: - Previews

#Preview("Valid row (auto-diagonal)") {
    @Previewable @State var values = [[0.9, 0.05, 0.05],
                                      [0.05, 0.9, 0.05],
                                      [0.05, 0.05, 0.9]]
    return MatrixDataRow(
        row: 0,
        values: $values,
        rowName: "Pop1",
        adjustDiagonalForRowStochastic: true
    )
    .padding()
}

#Preview("Invalid row") {
    @Previewable @State var values = [[0.5, 0.3, 0.3]]
    return MatrixDataRow(
        row: 0,
        values: $values,
        rowName: "Pop1",
        adjustDiagonalForRowStochastic: false
    )
    .padding()
}
#endif
