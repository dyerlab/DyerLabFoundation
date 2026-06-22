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

// MARK: - VectorCell

/// A single editable row in a `VectorView`, showing an element index, an optional label,
/// and a `TextField` bound to the element's value.
///
/// The row is tinted red when `validRange` is supplied and the current value falls outside it.
public struct VectorCell: View {

    // MARK: - Constants

    public struct Constants {
        /// Number of decimal places shown in the text field.
        public static let decimalPrecision: Int = 4
        /// Background tint when the value is outside the caller-supplied `validRange`.
        public static let outOfRangeBackground: Color = Color.red.opacity(0.07)
    }

    // MARK: - Properties

    /// The numeric value bound to this cell.
    @Binding public var value: Double

    /// Zero-based index shown in the leading column.
    public let index: Int

    /// Optional human-readable label for this element (e.g. population name, locus name).
    public let label: String

    /// When supplied, values outside this range trigger the invalid-row tint.
    public var validRange: ClosedRange<Double>?

    // MARK: - Computed helpers

    private var isValid: Bool {
        guard let range = validRange else { return true }
        return range.contains(value)
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 0) {
            Text("\(index)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: VectorView.Constants.indexWidth,
                       alignment: .trailing)
                .padding(.trailing, 6)

            if !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: VectorView.Constants.labelWidth,
                           alignment: .leading)
            }

            TextField(
                "",
                value: $value,
                format: .number.precision(.fractionLength(Constants.decimalPrecision))
            )
            #if os(macOS)
            .textFieldStyle(.plain)
            #endif
            .multilineTextAlignment(.trailing)
            .font(.body.monospacedDigit())
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .frame(height: VectorView.Constants.rowHeight)
        .background(isValid ? Color.clear : Constants.outOfRangeBackground)
        .border(Color.gray.opacity(0.12), width: 0.5)
    }

}
#if !SPM_BUILD

// MARK: - Previews

#Preview("Valid cell with label") {
    @Previewable @State var value = 0.4500
    return VectorCell(value: $value, index: 3, label: "Pop04", validRange: 0...1)
        .padding()
        .frame(width: 300)
}

#Preview("Invalid cell (out of range)") {
    @Previewable @State var value = 1.35
    return VectorCell(value: $value, index: 0, label: "L01", validRange: 0...1)
        .padding()
        .frame(width: 300)
}

#Preview("No label") {
    @Previewable @State var value = 3.14159
    return VectorCell(value: $value, index: 7, label: "")
        .padding()
        .frame(width: 240)
}
#endif
