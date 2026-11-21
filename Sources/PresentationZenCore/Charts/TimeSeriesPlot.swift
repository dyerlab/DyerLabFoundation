//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  TimeSeriesPlot.swift
//  PresentationZenCore
//
//  Created by Rodney Dyer on 2024.04.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Charts
import SwiftUI

/// A connected line/point series over time.
///
/// The x-axis kind is taken from the bound `x` column: a date column renders a
/// temporal axis, a numeric column renders an ordinal one. Binding a `series`
/// role with two or more groups colors the points and shows a legend; pass
/// `seriesColors` to pick those colors (every series value needs one).
///
/// Date charts can mark events (a change of method, a new version) with
/// dashed vertical rules.
public struct TimeSeriesPlot: View {
    /// The table to plot; bind a date or numeric `x` role and a quantitative `y` role (and optionally `series`).
    public var table: DataTable
    /// The y-axis title.
    public var yLabel: String
    /// The x-axis title; for a figure, inferred from `table`'s `x` column kind ("Date" or "Ordinal") when empty.
    public var xLabel: String
    /// The point color when no `series` role is bound (or only one group).
    public var soloColor: Color
    /// The connecting-line color.
    public var lineColor: Color
    /// Whether to draw y-axis tick marks and labels.
    public var yAxisTicksVisible: Bool
    /// Figure or compact chrome.
    public var style: PlotStyle
    /// The connecting line's dash pattern; empty for a solid line.
    public var lineDash: [CGFloat]
    /// Point colors by series value, replacing the automatic scale.
    public var seriesColors: [String: Color]?
    /// Whether to show the series legend when there are series.
    public var showsLegend: Bool
    /// Dates to mark with a dashed vertical rule (date axes only).
    public var events: [Date]
    /// Whether the y axis runs downward, for ranks where 1 is best.
    public var reversesYAxis: Bool
    /// Whether the y axis includes zero; `nil` lets Swift Charts decide.
    public var includesZero: Bool?
    /// Explicit y-axis tick values; `nil` lets Swift Charts choose.
    public var yAxisValues: [Double]?
    /// Formats y-axis labels; `nil` uses the default labels.
    public var formatYAxis: ((Double) -> String)?

    /// Creates a time series plot.
    ///
    /// - Parameters:
    ///   - table: The table to plot; bind a date or numeric `x` role and a quantitative `y`
    ///     role (and optionally `series`).
    ///   - yLabel: The y-axis title.
    ///   - xLabel: The x-axis title; for a figure, inferred from `table`'s `x` column kind
    ///     ("Date" or "Ordinal") when empty.
    ///   - ptColor: The point color when no `series` role is bound (or only one group);
    ///     points colored by `series` ignore this.
    ///   - lineColor: The connecting-line color.
    ///   - yAxisTicksVisible: Whether to draw y-axis tick marks and labels.
    ///   - style: Figure or compact chrome; compact charts show only the axis titles given.
    ///   - lineDash: The connecting line's dash pattern; empty for a solid line.
    ///   - seriesColors: Point colors by series value, replacing the automatic scale.
    ///   - showsLegend: Whether to show the series legend when there are series.
    ///   - events: Dates to mark with a dashed vertical rule (date axes only).
    ///   - reversesYAxis: Whether the y axis runs downward, for ranks where 1 is best.
    ///   - includesZero: Whether the y axis includes zero; `nil` lets Swift Charts decide.
    ///   - yAxisValues: Explicit y-axis tick values; `nil` lets Swift Charts choose.
    ///   - formatYAxis: Formats y-axis labels; `nil` uses the default labels.
    public init(_ table: DataTable,
                yLabel: String,
                xLabel: String = "",
                ptColor: Color = .orange,
                lineColor: Color = .gray,
                yAxisTicksVisible: Bool = true,
                style: PlotStyle = .figure,
                lineDash: [CGFloat] = [5.0, 5.0],
                seriesColors: [String: Color]? = nil,
                showsLegend: Bool = true,
                events: [Date] = [],
                reversesYAxis: Bool = false,
                includesZero: Bool? = nil,
                yAxisValues: [Double]? = nil,
                formatYAxis: ((Double) -> String)? = nil) {
        self.table = table
        self.yLabel = yLabel
        self.soloColor = ptColor
        self.lineColor = lineColor
        self.yAxisTicksVisible = yAxisTicksVisible
        self.style = style
        self.lineDash = lineDash
        self.seriesColors = seriesColors
        self.showsLegend = showsLegend
        self.events = events
        self.reversesYAxis = reversesYAxis
        self.includesZero = includesZero
        self.yAxisValues = yAxisValues
        self.formatYAxis = formatYAxis
        if xLabel.isEmpty, style == .figure {
            self.xLabel = table.xKind == .date ? "Date" : "Ordinal"
        } else {
            self.xLabel = xLabel
        }
    }

    private var grouped: Bool { table.seriesValues.count >= 2 }

    // MARK: - Per-kind content (no `if/else` at ChartContent level)

    @ChartContentBuilder
    private var dateContent: some ChartContent {
        ForEach(events, id: \.self) { date in
            RuleMark(x: .value("Event", date))
                .foregroundStyle(Color.secondary.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        ForEach(table.plotRows) { row in
            if let date = row.x.dateValue {
                LineMark(x: .value("X Value", date),
                         y: .value(yLabel, row.y))
                .foregroundStyle(lineColor)
                .lineStyle(.init(dash: lineDash))
            }
        }
        ForEach(table.plotRows) { row in
            if let date = row.x.dateValue {
                PointMark(x: .value("X Value", date),
                          y: .value(yLabel, row.y))
                .foregroundStyle(by: .value("Category", row.series ?? ""))
            }
        }
    }

    @ChartContentBuilder
    private var ordinalContent: some ChartContent {
        ForEach(table.plotRows) { row in
            LineMark(x: .value("X Value", row.xDouble),
                     y: .value(yLabel, row.y))
            .foregroundStyle(lineColor)
            .lineStyle(.init(dash: lineDash))
        }
        ForEach(table.plotRows) { row in
            PointMark(x: .value("X Value", row.xDouble),
                      y: .value(yLabel, row.y))
            .foregroundStyle(by: .value("Category", row.series ?? ""))
        }
    }

    // MARK: - Body (x-kind branch lives at the View level)

    public var body: some View {
        Group {
            switch table.xKind {
            case .date:
                styled(Chart { dateContent })
            default:
                styled(Chart { ordinalContent })
            }
        }
        .frame(minHeight: style == .figure ? 300 : nil)
    }

    /// Applies the shared styling/labels to either chart variant.
    private func styled<Content: View>(_ chart: Content) -> some View {
        titled(colored(chart)
            .chartYScale(domain: .automatic(includesZero: includesZero, reversed: reversesYAxis ? true : nil))
            .chartYAxis {
                if let yAxisValues {
                    AxisMarks(values: yAxisValues) { value in
                        AxisGridLine()
                        AxisValueLabel { yAxisText(value.as(Double.self)) }
                    }
                } else if style == .compact {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel { yAxisText(value.as(Double.self)) }
                    }
                } else if yAxisTicksVisible {
                    AxisMarks { AxisValueLabel() }
                }
            })
    }

    /// A y-axis label: formatted when a formatter is given.
    private func yAxisText(_ value: Double?) -> Text {
        guard let value else { return Text(verbatim: "") }
        return Text(formatYAxis?(value) ?? value.formatted())
    }

    /// The series color scale and legend.
    @ViewBuilder
    private func colored<Content: View>(_ chart: Content) -> some View {
        if let seriesColors {
            let sorted = seriesColors.sorted { $0.key < $1.key }
            chart
                .chartForegroundStyleScale(domain: sorted.map(\.key), range: sorted.map(\.value))
                .chartLegend(showsLegend ? .automatic : .hidden)
        } else if showsLegend {
            chart.seriesStyle(hasSeries: grouped, soloColor: soloColor)
        } else {
            chart.seriesStyle(hasSeries: false, soloColor: soloColor)
        }
    }

    /// The axis titles for the style.
    @ViewBuilder
    private func titled<Content: View>(_ chart: Content) -> some View {
        switch style {
        case .figure:
            chart
                .chartXAxisLabel(position: .bottom, alignment: .center) {
                    Text(xLabel).font(.headline)
                }
                .chartYAxisLabel(position: .trailing, alignment: .center) {
                    Text(yLabel).font(.title3)
                }
        case .compact:
            chart.compactAxisTitles(x: xLabel, y: yLabel)
        }
    }
}

// MARK: - Previews

#Preview("Date") {
    TimeSeriesPlot(.sampleTemporal, yLabel: "Y-Axis Data")
        .padding()
}

#Preview("Ordinal") {
    TimeSeriesPlot(.sampleScatter, yLabel: "Y-Axis Data")
        .padding()
}

#Preview("Compact, ranked, with events") {
    let days = (0 ..< 6).map { Date(timeIntervalSince1970: Double($0) * 86_400 * 3) }
    let table = DataTable(numbers: ["place": [3, 1, 2, 4, 1, 2]],
                          dates: ["date": days],
                          strings: ["result": ["Other", "Win", "Other", "Other", "Win", "Other"]],
                          roles: [.x: "date", .y: "place", .series: "result"])
    TimeSeriesPlot(table, yLabel: "", ptColor: .accentColor, lineColor: .accentColor.opacity(0.4),
                   style: .compact, lineDash: [], seriesColors: ["Win": .yellow, "Other": .accentColor],
                   showsLegend: false, events: [days[3]], reversesYAxis: true, yAxisValues: [1, 2, 3, 4],
                   formatYAxis: { "#\(Int($0))" })
        .frame(height: 180)
        .padding()
}
