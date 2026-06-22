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

// MARK: - VectorStatsRow

/// A read-only summary footer displaying key statistics for a `Vector`.
///
/// Shows count, sum, mean, and the min/max range.  Placed at the bottom of a
/// `VectorView` to give the user a quick sanity-check without leaving the editor.
public struct VectorStatsRow: View {

    // MARK: - Constants

    public struct Constants {
        /// Number of decimal places in each statistic label.
        public static let decimalPrecision: Int = 4
    }

    // MARK: - Properties

    /// The vector whose statistics are displayed.
    public let values: Vector

    // MARK: - Computed helpers

    private func formatted(_ value: Double) -> String {
        value.isNaN
            ? "—"
            : String(format: "%.\(Constants.decimalPrecision)f", value)
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 16) {
            statItem(label: "n",   value: "\(values.count)")
            statItem(label: "Σ",   value: formatted(values.sum))
            statItem(label: "μ",   value: formatted(values.mean))
            statItem(label: "min", value: formatted(values.minimum ?? .nan))
            statItem(label: "max", value: formatted(values.maximum ?? .nan))
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(uiColor: .secondarySystemBackground))
        #endif
    }

    // MARK: - Private subview

    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.primary)
        }
    }

}
#if !SPM_BUILD

// MARK: - Previews

#Preview("Frequency vector stats") {
    let values: Vector = [0.4, 0.25, 0.15, 0.1, 0.1]
    return VectorStatsRow(values: values)
        .frame(width: 400)
}

#Preview("Empty vector stats") {
    VectorStatsRow(values: [])
        .frame(width: 400)
}
#endif
