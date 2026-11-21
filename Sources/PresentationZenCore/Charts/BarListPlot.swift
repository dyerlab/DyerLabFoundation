//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  BarListPlot.swift
//  PresentationZenCore
//
//  Drawn as a grid rather than with Swift Charts: with a categorical y axis, Charts put each name in the gap above
//  its bar (where it reads as the previous bar's label) or clip it. Here each row is name, bar, value on one line,
//  and long names truncate so the bars keep their room.
//
//  Created by Rodney Dyer on 2026.11.20.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// Horizontal bars, one row per category in table order, each with its name before it and its value after it.
///
/// Bind a categorical `x` role (the names) and a quantitative `y` role (the lengths). Bars are scaled to the
/// largest value.
public struct BarListPlot: View {
    /// The table to plot; bind categorical `x` and quantitative `y` roles.
    public var table: DataTable
    /// The bar color; `nil` uses the environment's tint.
    public var barColor: Color?
    /// The widest a name may be before it truncates.
    public var nameWidth: CGFloat
    /// What to show when the table has no rows.
    public var emptyText: String
    /// Formats the value shown after each bar.
    public var formatValue: (Double) -> String

    /// Creates a bar list.
    ///
    /// - Parameters:
    ///   - table: The table to plot; bind categorical `x` and quantitative `y` roles.
    ///   - barColor: The bar color; `nil` uses the environment's tint.
    ///   - nameWidth: The widest a name may be before it truncates.
    ///   - emptyText: What to show when the table has no rows.
    ///   - formatValue: Formats the value shown after each bar.
    public init(_ table: DataTable,
                barColor: Color? = nil,
                nameWidth: CGFloat = 140,
                emptyText: String = "",
                formatValue: @escaping (Double) -> String = { $0.formatted() }) {
        self.table = table
        self.barColor = barColor
        self.nameWidth = nameWidth
        self.emptyText = emptyText
        self.formatValue = formatValue
    }

    public var body: some View {
        let rows = table.plotRows
        if rows.isEmpty {
            Text(emptyText)
                .foregroundStyle(.secondary)
        } else {
            let largest = rows.map(\.y).max() ?? 0
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                ForEach(rows) { row in
                    let name = row.x.stringValue ?? row.xDouble.formatted()
                    GridRow {
                        Text(name)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: nameWidth, alignment: .leading)
                        BarListBar(value: formatValue(row.y),
                                   fraction: largest > 0 ? row.y / largest : 0,
                                   color: barColor)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(name)
                    .accessibilityValue(formatValue(row.y))
                }
            }
            .font(.subheadline)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Previews

#Preview("Bars") {
    BarListPlot(.sampleBars)
        .padding()
}

#Preview("Empty") {
    BarListPlot(DataTable(numbers: [:]), emptyText: "Nothing yet")
        .padding()
}
