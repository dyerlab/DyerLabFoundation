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

// MARK: - VectorView

/// A scrollable, fully editable view for a `Vector` (`[Double]`).
///
/// Composes `VectorCell` rows and a `VectorStatsRow` footer.  An optional
/// `labels` array provides human-readable names for each element (e.g. population
/// names alongside migration rates, locus names alongside allele frequencies).
/// When `labels` is shorter than `values`, unlabelled elements show an empty label.
///
/// An optional `validRange` is forwarded to every `VectorCell`; elements outside the
/// range are tinted red, giving the user immediate visual feedback.
///
/// ## Usage
///
/// ```swift
/// @State var rates: Vector = [0.1, 0.05, 0.05, 0.1]
/// let pops = ["Pop1", "Pop2", "Pop3", "Pop4"]
///
/// VectorView(values: $rates, labels: pops, title: "Migration Rates",
///            validRange: 0...1)
/// ```
public struct VectorView: View {

    // MARK: - Layout constants

    /// Shared layout metrics used by `VectorCell`.
    public struct Constants {
        /// Width of the leading zero-based index column.
        public static let indexWidth: CGFloat   = 32
        /// Width of the optional element-label column.
        public static let labelWidth: CGFloat   = 88
        /// Height of each data row.
        public static let rowHeight: CGFloat    = 30
    }

    // MARK: - Properties

    /// The vector values to display and edit.
    @Binding public var values: Vector

    /// Optional per-element labels (e.g. population or locus names).
    public var labels: [String]

    /// Optional title shown above the list.
    public var title: String?

    /// When supplied, values outside this range are highlighted in red.
    public var validRange: ClosedRange<Double>?

    // MARK: - Init

    /// Creates a `VectorView`.
    ///
    /// - Parameters:
    ///   - values: Binding to the vector values.
    ///   - labels: Optional human-readable label for each element.
    ///   - title: Optional heading above the list.
    ///   - validRange: Optional range used for per-cell validation colouring.
    public init(
        values: Binding<Vector>,
        labels: [String] = [],
        title: String? = nil,
        validRange: ClosedRange<Double>? = nil
    ) {
        self._values = values
        self.labels = labels
        self.title = title
        self.validRange = validRange
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                Divider()
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<values.count, id: \.self) { index in
                        VectorCell(
                            value: $values[index],
                            index: index,
                            label: index < labels.count ? labels[index] : "",
                            validRange: validRange
                        )
                    }
                }
            }

            Divider()
            VectorStatsRow(values: values)
        }
    }

}
#if !SPM_BUILD

// MARK: - Previews

#Preview("Migration rates with population labels") {
    @Previewable @State var rates: Vector = [0.10, 0.05, 0.03, 0.08, 0.12]
    let pops = ["Pop01", "Pop02", "Pop03", "Pop04", "Pop05"]
    return VectorView(values: $rates, labels: pops,
                      title: "Migration Rates", validRange: 0...1)
        .frame(width: 320, height: 280)
}

#Preview("Allele frequencies (one invalid)") {
    @Previewable @State var freqs: Vector = [0.60, 0.25, 1.20, 0.10]
    let loci = ["L01", "L02", "L03", "L04"]
    return VectorView(values: $freqs, labels: loci,
                      title: "Allele Frequencies", validRange: 0...1)
        .frame(width: 300, height: 240)
}

#Preview("Unlabelled vector") {
    @Previewable @State var values: Vector = [1.0, 2.0, 3.0, 4.0, 5.0]
    return VectorView(values: $values)
        .frame(width: 240, height: 260)
}
#endif
