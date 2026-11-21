//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GroupedBarPlot.swift
//  PresentationZenCore
//
//  Hue carries the category and lightness carries the series, so two measures of the same thing (cost and
//  production of a color, before and after a treatment) stand side by side in the same color. The category
//  axis labels come from a view builder, so an app can label a category with a symbol rather than text.
//
//  Created by Rodney Dyer on 2026.11.20.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Charts
import SwiftUI

/// Side-by-side bars per category, one bar per series, colored by category and shaded by series, with a legend.
///
/// Bind a categorical `x` role, a quantitative `y` role and a `series` role. Series keep the order they first
/// appear in the table.
public struct GroupedBarPlot<CategoryLabel: View>: View {
    /// The table to plot; bind categorical `x`, quantitative `y` and `series` roles.
    public var table: DataTable
    /// Colors by category; categories without one use `defaultColor`.
    public var categoryColors: [String: Color]
    /// The color of a category with no entry in `categoryColors`.
    public var defaultColor: Color
    /// The opacity of each series' bars, in series order; later series reuse the last value.
    public var seriesOpacity: [Double]
    /// Whether to draw the series legend below the chart.
    public var showsLegend: Bool
    /// Formats the y-axis values; `nil` uses the default labels.
    public var formatYAxis: ((Double) -> String)?
    /// Draws a category's axis label.
    public var categoryLabel: (String) -> CategoryLabel

    /// Creates a grouped bar plot.
    ///
    /// - Parameters:
    ///   - table: The table to plot; bind categorical `x`, quantitative `y` and `series` roles.
    ///   - categoryColors: Colors by category; categories without one use `defaultColor`.
    ///   - defaultColor: The color of a category with no entry in `categoryColors`.
    ///   - seriesOpacity: The opacity of each series' bars, in series order; later series reuse the last value.
    ///   - showsLegend: Whether to draw the series legend below the chart.
    ///   - formatYAxis: Formats the y-axis values; `nil` uses the default labels.
    ///   - categoryLabel: Draws a category's axis label.
    public init(_ table: DataTable,
                categoryColors: [String: Color] = [:],
                defaultColor: Color = .accentColor,
                seriesOpacity: [Double] = [1, 0.45],
                showsLegend: Bool = true,
                formatYAxis: ((Double) -> String)? = nil,
                @ViewBuilder categoryLabel: @escaping (String) -> CategoryLabel) {
        self.table = table
        self.categoryColors = categoryColors
        self.defaultColor = defaultColor
        self.seriesOpacity = seriesOpacity.isEmpty ? [1] : seriesOpacity
        self.showsLegend = showsLegend
        self.formatYAxis = formatYAxis
        self.categoryLabel = categoryLabel
    }

    /// The series in the order they first appear.
    var seriesOrder: [String] {
        var seen = Set<String>()
        return table.plotRows.compactMap { row in
            let series = row.series ?? ""
            return seen.insert(series).inserted ? series : nil
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            chart
            if showsLegend {
                HStack(spacing: 16) {
                    ForEach(Array(seriesOrder.enumerated()), id: \.element) { index, series in
                        Label {
                            Text(series)
                        } icon: {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.secondary.opacity(opacity(at: index)))
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var chart: some View {
        let order = seriesOrder
        return Chart(table.plotRows) { row in
            let category = row.x.stringValue ?? row.xDouble.formatted()
            let index = order.firstIndex(of: row.series ?? "") ?? 0
            BarMark(x: .value("Category", category), y: .value("Value", row.y))
                .foregroundStyle((categoryColors[category] ?? defaultColor).opacity(opacity(at: index)))
                .position(by: .value("Series", row.series ?? ""))
                .cornerRadius(3)
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let category = value.as(String.self) { categoryLabel(category) }
                }
            }
        }
        .chartYAxis {
            if let formatYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let number = value.as(Double.self) { Text(formatYAxis(number)) }
                    }
                }
            } else {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
        }
    }

    private func opacity(at index: Int) -> Double {
        seriesOpacity[min(index, seriesOpacity.count - 1)]
    }
}

// MARK: - Previews

#Preview {
    let table = DataTable(numbers: ["share": [0.4, 0.35, 0.6, 0.5, 0.0, 0.15]],
                          strings: ["color": ["Red", "Red", "Blue", "Blue", "Gray", "Gray"],
                                    "measure": ["Cost", "Production", "Cost", "Production", "Cost", "Production"]],
                          roles: [.x: "color", .y: "share", .series: "measure"])
    GroupedBarPlot(table,
                   categoryColors: ["Red": .red, "Blue": .blue, "Gray": .gray],
                   formatYAxis: { $0.formatted(.percent.precision(.fractionLength(0))) })
        .frame(height: 220)
        .padding()
}
