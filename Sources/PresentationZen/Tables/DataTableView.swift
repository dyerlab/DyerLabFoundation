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
//  DataTableView.swift
//
//  Created by Rodney Dyer on 2/10/24.
//

import SwiftUI
import TabularData

/// A simple grid view of a ``DataTable``. Column headers come from the table's
/// column names; cells are formatted by kind (numbers via `formatString`,
/// dates abbreviated, strings verbatim).
public struct DataTableView: View {
    public var table: DataTable
    public var formatString: String
    public var minColWidth: Double
    public var caption: String?

    private var inScrollView: Bool

    /// Creates a table view.
    ///
    /// - Parameters:
    ///   - table: The table to display.
    ///   - formatString: The `String(format:)` pattern used for numeric columns.
    ///   - minColWidth: The minimum width of each column.
    ///   - inScrollView: Whether to wrap the grid in a horizontally-scrolling container.
    ///   - caption: An optional caption drawn below the grid.
    public init(_ table: DataTable,
                formatString: String = "%.4f",
                minColWidth: Double = 150,
                inScrollView: Bool = true,
                caption: String? = nil) {
        self.table = table
        self.formatString = formatString
        self.minColWidth = minColWidth
        self.inScrollView = inScrollView
        self.caption = caption
    }

    /// Pre-rendered display strings, one entry per column.
    private var displayColumns: [(name: String, values: [String], kind: ColumnKind?)] {
        table.columnNames.map { name in
            let kind = table.kind(of: name)
            switch kind {
            case .number:
                let values = table.numericColumn(name).map { value in
                    value.map { String(format: formatString, $0) } ?? ""
                }
                return (name, values, kind)
            case .date:
                let values = Array(table.frame[name, Date.self]).map { date in
                    date?.formatted(date: .abbreviated, time: .omitted) ?? ""
                }
                return (name, values, kind)
            case .category, .none:
                return (name, table.stringColumn(name).map { $0 ?? "" }, kind)
            }
        }
    }

    /// Categories and dates read as left-justified text; numbers stay centered.
    private func alignment(for kind: ColumnKind?) -> Alignment {
        kind == .number ? .center : .leading
    }

    private var gridColumns: [GridItem] {
        table.columnNames.map { _ in
            GridItem(.flexible(minimum: minColWidth, maximum: .infinity))
        }
    }

    private var tableContent: some View {
        let cols = displayColumns
        let colCount = cols.count
        // A single flat ForEach, not a ForEach nested inside another ForEach —
        // LazyVGrid doesn't reliably flatten the nested form into one cell per
        // view, which silently drops every data row while the header (a lone
        // top-level ForEach) still renders.
        return LazyVGrid(columns: gridColumns) {
            ForEach(cols.indices, id: \.self) { c in
                Text(cols[c].name.capitalized)
                    .frame(maxWidth: .infinity, alignment: alignment(for: cols[c].kind))
                    .font(.headline)
            }
            ForEach(0 ..< (table.rowCount * colCount), id: \.self) { i in
                let r = i / colCount
                let c = i % colCount
                Text(r < cols[c].values.count ? cols[c].values[r] : "")
                    .frame(maxWidth: .infinity, alignment: alignment(for: cols[c].kind))
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var captionText: some View {
        if let caption {
            Text(caption)
                .font(.title3)
                .bold()
        }
    }

    public var body: some View {
        if inScrollView {
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading) {
                    captionText
                    tableContent
                }
            }
        } else {
            VStack(alignment: .leading) {
                captionText
                tableContent
            }
            .padding()
        }
    }
}
#if !SPM_BUILD

#Preview {
    DataTableView(.sampleScatter, caption: "Scatter Sample")
}
#endif
