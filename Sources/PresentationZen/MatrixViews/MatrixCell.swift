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

// MARK: - MatrixCell

/// A single editable (or read-only) cell in a migration-matrix grid.
///
/// When `isReadOnly` is `true` the cell displays its value as formatted text and does not
/// accept keyboard input.  This is used for diagonal cells when auto-diagonal adjustment is
/// active, because the diagonal value is computed rather than entered directly.
///
/// Cell width and height are inherited from `MatrixView.Constants` so that all cells in
/// a `MatrixView` align with the column headers.
public struct MatrixCell: View {

    // MARK: - Constants

    public struct Constants {
        /// Number of decimal places shown in every cell.
        public static let decimalPrecision: Int = 4
        /// Background tint applied to diagonal cells.
        public static let diagonalBackground: Color = Color.accentColor.opacity(0.08)
    }

    // MARK: - Properties

    /// The numeric value bound to this cell.
    @Binding public var value: Double

    /// Whether this cell sits on the matrix diagonal.
    public let isDiagonal: Bool

    /// When `true` the cell is displayed as plain text and cannot be edited.
    public let isReadOnly: Bool

    // MARK: - Body

    public var body: some View {
        Group {
            if isReadOnly {
                Text(String(format: "%.\(Constants.decimalPrecision)f", value))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                TextField(
                    "",
                    value: $value,
                    format: .number.precision(.fractionLength(Constants.decimalPrecision))
                )
                #if os(macOS)
                .textFieldStyle(.plain)
                #endif
                .multilineTextAlignment(.center)
                .font(.body.monospacedDigit())
            }
        }
        .frame(width: MatrixView.Constants.cellWidth,
               height: MatrixView.Constants.rowHeight)
        .background(isDiagonal ? Constants.diagonalBackground : Color.clear)
        .border(Color.gray.opacity(0.15), width: 0.5)
    }

}
#if !SPM_BUILD

// MARK: - Previews

#Preview("Editable cell") {
    @Previewable @State var value = 0.1234
    return MatrixCell(value: $value, isDiagonal: false, isReadOnly: false)
        .padding()
}

#Preview("Diagonal (read-only)") {
    @Previewable @State var value = 0.8766
    return MatrixCell(value: $value, isDiagonal: true, isReadOnly: true)
        .padding()
}
#endif
