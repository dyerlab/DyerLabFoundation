//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  TabularOutputView.swift
//  PresentationZen
//
//  A results table laid out the way a journal prints one: rules above and
//  below the header and at the foot, text left-aligned, numbers right-aligned
//  with whole-number columns (such as df) shown without decimals and missing
//  values left blank. `DataTableView` is the scrolling grid for data; this is
//  for a handful of rows of output.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// A small results table, such as an AMOVA table, in publication style.
public struct TabularOutputView: View {

    /// How large the table is drawn.
    public enum Size: Sendable {
        /// The table on a page.
        case regular
        /// A thumbnail of the table, as in a list of saved figures.
        case compact
    }

    /// The values.
    public let table: DataTable
    /// A title above the table, if any.
    public let title: String?
    /// A caption below the table, if any.
    public let caption: String?
    /// Headers to show instead of column names, such as `Φ_ST` for `Phi_ST`.
    public let headers: [String: String]
    /// The decimal places for numbers that aren't whole.
    public let decimals: Int
    /// How large the table is drawn.
    public let size: Size

    /// Creates the view.
    ///
    /// - Parameters:
    ///   - table: The values.
    ///   - title: A title above the table.
    ///   - caption: A caption below the table.
    ///   - headers: Headers to show instead of column names.
    ///   - decimals: The decimal places for numbers that aren't whole.
    ///   - size: How large the table is drawn.
    public init(_ table: DataTable,
                title: String? = nil,
                caption: String? = nil,
                headers: [String: String] = [:],
                decimals: Int = DataTable.defaultDecimals,
                size: Size = .regular) {
        self.table = table
        self.title = title
        self.caption = caption
        self.headers = headers
        self.decimals = decimals
        self.size = size
    }

    private var columns: [(header: String, values: [String], isNumber: Bool)] {
        table.columnNames.map { name in
            (headers[name] ?? name, table.displayTexts(name, decimals: decimals), table.kind(of: name) == .number)
        }
    }

    public var body: some View {
        let columns = columns
        VStack(alignment: .leading, spacing: size == .compact ? 4 : 10) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(size == .compact ? .caption.bold() : .headline)
            }
            Grid(alignment: .trailing, horizontalSpacing: size == .compact ? 8 : 24,
                 verticalSpacing: size == .compact ? 2 : 6) {
                Divider()
                GridRow {
                    ForEach(columns.indices, id: \.self) { c in
                        Text(columns[c].header)
                            .bold()
                            .gridColumnAlignment(columns[c].isNumber ? .trailing : .leading)
                    }
                }
                Divider()
                ForEach(0..<table.rowCount, id: \.self) { row in
                    GridRow {
                        ForEach(columns.indices, id: \.self) { c in
                            Text(columns[c].values[row])
                                .monospacedDigit()
                                .textSelection(.enabled)
                        }
                    }
                }
                Divider()
            }
            .font(size == .compact ? .caption2 : .body)
            .fixedSize()
            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(size == .compact ? .caption2 : .callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Previews

#Preview("AMOVA") {
    let amova = DataTable(figureColumns: [
        FigureColumn(name: "Source", values: .text(["Population", "Error", "Total"])),
        FigureColumn(name: "df", values: .numbers([37, 291, 328])),
        FigureColumn(name: "SS", values: .numbers([1499.1891, 982.8778, 2482.0669])),
        FigureColumn(name: "MS", values: .numbers([40.5186, 3.3776, nil])),
        FigureColumn(name: "Phi_ST", values: .numbers([0.5601, nil, nil])),
        FigureColumn(name: "P", values: .numbers([0.001, nil, nil])),
    ]) ?? DataTable(numbers: [:])
    TabularOutputView(amova, title: "AMOVA among populations",
                      caption: "AMOVA of individuals among populations at all loci, summarized as Φ_ST.",
                      headers: ["Phi_ST": "Φ_ST"])
        .padding()
}

#Preview("Compact") {
    let amova = DataTable(figureColumns: [
        FigureColumn(name: "Source", values: .text(["Family", "Error", "Total"])),
        FigureColumn(name: "df", values: .numbers([9, 90, 99])),
        FigureColumn(name: "Phi_ST", values: .numbers([0.21, nil, nil])),
    ]) ?? DataTable(numbers: [:])
    TabularOutputView(amova, size: .compact)
        .padding()
}
