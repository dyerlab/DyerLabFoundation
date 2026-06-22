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

// MARK: - MatrixHeaderRow

/// The sticky column-name header for a `MatrixView`.
///
/// Renders a row containing an empty corner spacer, one label per column name,
/// and a trailing "Sum" label.  All widths are taken from `MatrixView.Constants`
/// so the headers align precisely with the data cells below.
public struct MatrixHeaderRow: View {

    // MARK: - Properties

    /// Ordered column names to display.
    public let colNames: [String]

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 0) {
            // Corner spacer aligns with the row-name column
            Text("")
                .frame(width: MatrixView.Constants.headerWidth,
                       height: MatrixView.Constants.rowHeight)

            ForEach(colNames, id: \.self) { name in
                Text(name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: MatrixView.Constants.cellWidth,
                           height: MatrixView.Constants.rowHeight)
            }

            Text("Sum")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: MatrixView.Constants.sumWidth,
                       height: MatrixView.Constants.rowHeight)
        }
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(uiColor: .secondarySystemBackground))
        #endif
    }

}
#if !SPM_BUILD

// MARK: - Previews

#Preview("3-column header") {
    MatrixHeaderRow(colNames: ["Pop1", "Pop2", "Pop3"])
        .padding(.vertical, 4)
}

#Preview("Long names truncate") {
    MatrixHeaderRow(colNames: ["LongPopulationName01", "LongPopulationName02"])
        .padding(.vertical, 4)
}
#endif
