//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  SequencePlot.swift
//  PresentationZenCore
//
//  Values in the order they happened (game 1, 2, 3, ...), where the time between them doesn't matter. Each value is
//  a dot, a trend (a rolling average, say) runs through them as a line, bands shade the stretches that belong
//  together, and dashed rules mark what happened between two positions. MyDeck plots a deck's games this way, with a
//  band per deck version and a rule where the deck changed.
//
//  Created by Rodney Dyer on 2026.11.27.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Charts
import SwiftUI

/// Values by position, with a trend line, shaded bands and marker rules.
///
/// Bind a numeric `x` role (positions 1, 2, 3, ...) and a quantitative `y` role; a `series` role colors the dots
/// (pass `seriesColors` to pick the colors). `trend` is a second table with the same roles, drawn as a line.
public struct SequencePlot: View {
    /// The values, one dot each.
    public var table: DataTable
    /// A line drawn through the values, such as a rolling average; `nil` for none.
    public var trend: DataTable?
    /// Stretches shaded behind the marks.
    public var bands: [SequenceBand]
    /// Dashed rules between positions.
    public var markers: [SequenceMarker]
    /// The y-axis title.
    public var yLabel: String
    /// The x-axis title.
    public var xLabel: String
    /// The dot color when no `series` role is bound.
    public var pointColor: Color
    /// The trend line's color.
    public var trendColor: Color
    /// The fill of shaded bands.
    public var bandColor: Color
    /// Dot colors by series value, replacing the automatic scale.
    public var seriesColors: [String: Color]?
    /// Figure or compact chrome.
    public var style: PlotStyle
    /// The y axis's range; `nil` lets Swift Charts decide.
    public var yDomain: ClosedRange<Double>?
    /// Explicit y-axis tick values; `nil` lets Swift Charts choose.
    public var yAxisValues: [Double]?
    /// Formats y-axis labels; `nil` uses the default labels.
    public var formatYAxis: ((Double) -> String)?

    /// Creates a sequence plot.
    ///
    /// - Parameters:
    ///   - table: The values; bind a numeric `x` role and a quantitative `y` role (and optionally `series`).
    ///   - trend: A line through the values, with the same roles; `nil` for none.
    ///   - bands: Stretches shaded behind the marks.
    ///   - markers: Dashed rules between positions.
    ///   - yLabel: The y-axis title.
    ///   - xLabel: The x-axis title.
    ///   - pointColor: The dot color when no `series` role is bound.
    ///   - trendColor: The trend line's color.
    ///   - bandColor: The fill of shaded bands.
    ///   - seriesColors: Dot colors by series value; every series value needs one.
    ///   - style: Figure or compact chrome; compact charts show only the axis titles given.
    ///   - yDomain: The y axis's range; `nil` lets Swift Charts decide.
    ///   - yAxisValues: Explicit y-axis tick values; `nil` lets Swift Charts choose.
    ///   - formatYAxis: Formats y-axis labels; `nil` uses the default labels.
    public init(_ table: DataTable,
                trend: DataTable? = nil,
                bands: [SequenceBand] = [],
                markers: [SequenceMarker] = [],
                yLabel: String = "",
                xLabel: String = "",
                pointColor: Color = .accentColor,
                trendColor: Color = .accentColor,
                bandColor: Color = .secondary,
                seriesColors: [String: Color]? = nil,
                style: PlotStyle = .figure,
                yDomain: ClosedRange<Double>? = nil,
                yAxisValues: [Double]? = nil,
                formatYAxis: ((Double) -> String)? = nil) {
        self.table = table
        self.trend = trend
        self.bands = bands
        self.markers = markers
        self.yLabel = yLabel
        self.xLabel = xLabel
        self.pointColor = pointColor
        self.trendColor = trendColor
        self.bandColor = bandColor
        self.seriesColors = seriesColors
        self.style = style
        self.yDomain = yDomain
        self.yAxisValues = yAxisValues
        self.formatYAxis = formatYAxis
    }

    // MARK: - Axis

    /// The x axis's range: every position, band and marker, with half a step to spare at each end.
    var xDomain: ClosedRange<Double> {
        let positions = table.plotRows.map(\.xDouble).filter(\.isFinite)
        let edges = positions.flatMap { [$0 - 0.5, $0 + 0.5] } + bands.flatMap { [$0.start, $0.end] }
            + markers.map(\.position)
        guard let lower = edges.min(), let upper = edges.max(), lower < upper else { return 0.5 ... 1.5 }
        return lower ... upper
    }

    /// Whole-number ticks across the x axis, no more than `desired` of them, starting at the first position.
    ///
    /// - Parameter desired: The most ticks to show.
    /// - Returns: The tick positions.
    func xAxisValues(desired: Int = 6) -> [Double] {
        let domain = xDomain
        let first = Int(domain.lowerBound.rounded(.up))
        let last = Int(domain.upperBound.rounded(.down))
        guard first <= last else { return [] }
        let span = last - first
        let steps = [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1_000]
        let step = steps.first { span / $0 + 1 <= max(desired, 1) } ?? max(span / max(desired - 1, 1), 1)
        return stride(from: first, through: last, by: step).map(Double.init)
    }

    // MARK: - Content

    @ChartContentBuilder
    private var content: some ChartContent {
        ForEach(bands) { band in
            RectangleMark(xStart: .value("Start", band.start), xEnd: .value("End", band.end))
                .foregroundStyle(bandColor.opacity(band.isShaded ? 0.12 : 0))
                .annotation(position: .overlay, alignment: .topLeading, spacing: 2) {
                    Text(band.label ?? "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 3)
                }
        }
        ForEach(markers) { marker in
            RuleMark(x: .value("Marker", marker.position))
                .foregroundStyle(Color.secondary.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .annotation(position: .trailing, alignment: .top, spacing: 2) {
                    Text(marker.label ?? "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
        }
        ForEach(trend?.plotRows ?? []) { row in
            LineMark(x: .value("Position", row.xDouble), y: .value("Trend", row.y), series: .value("Line", "Trend"))
                .foregroundStyle(trendColor)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
        }
        ForEach(table.plotRows) { row in
            PointMark(x: .value("Position", row.xDouble), y: .value(yLabel, row.y))
                .foregroundStyle(by: .value("Category", row.series ?? ""))
                .symbolSize(style == .compact ? 30 : 50)
        }
    }

    // MARK: - Body

    public var body: some View {
        titled(scaled(colored(Chart { content }))
            .chartXScale(domain: xDomain)
            .chartXAxis {
                AxisMarks(values: xAxisValues()) { value in
                    AxisGridLine()
                    AxisValueLabel { Text(verbatim: value.as(Double.self).map { "\(Int($0))" } ?? "") }
                }
            }
            .chartYAxis {
                if let yAxisValues {
                    AxisMarks(values: yAxisValues) { value in
                        AxisGridLine()
                        AxisValueLabel { yAxisText(value.as(Double.self)) }
                    }
                } else {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel { yAxisText(value.as(Double.self)) }
                    }
                }
            })
            .frame(minHeight: style == .figure ? 300 : nil)
    }

    /// A y-axis label: formatted when a formatter is given.
    private func yAxisText(_ value: Double?) -> Text {
        guard let value else { return Text(verbatim: "") }
        return Text(formatYAxis?(value) ?? value.formatted())
    }

    /// The y scale: the given range, or Swift Charts' own.
    @ViewBuilder
    private func scaled<Content: View>(_ chart: Content) -> some View {
        if let yDomain {
            chart.chartYScale(domain: yDomain)
        } else {
            chart
        }
    }

    /// The dot colors; series show no legend, so callers explain them beside the chart.
    @ViewBuilder
    private func colored<Content: View>(_ chart: Content) -> some View {
        if let seriesColors {
            let sorted = seriesColors.sorted { $0.key < $1.key }
            chart
                .chartForegroundStyleScale(domain: sorted.map(\.key), range: sorted.map(\.value))
                .chartLegend(.hidden)
        } else {
            chart.seriesStyle(hasSeries: false, soloColor: pointColor)
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

#Preview("Games by version") {
    let scores: [Double] = [1, 0.33, 0, 0.67, 1, 1, 0.33, 0.67, 0, 1, 1, 0.67]
    let positions = (1 ... scores.count).map(Double.init)
    let results = scores.map { $0 == 1 ? "Win" : "Other" }
    let table = DataTable(numbers: ["game": positions, "score": scores], strings: ["result": results],
                          roles: [.x: "game", .y: "score", .series: "result"])
    let rolling = scores.indices.map { index in
        let window = scores[max(0, index - 4) ... index]
        return window.reduce(0, +) / Double(window.count)
    }
    let trend = DataTable(numbers: ["game": positions, "rolling": rolling], roles: [.x: "game", .y: "rolling"])
    SequencePlot(table, trend: trend,
                 bands: [.covering(1, through: 4, label: "v1"), .covering(5, through: 9, label: "v2", isShaded: false),
                         .covering(10, through: 12, label: "v3")],
                 markers: [.after(4, label: "Changed"), .after(9, label: "2 changes")],
                 xLabel: "Game", seriesColors: ["Win": .yellow, "Other": .accentColor], style: .compact,
                 yDomain: 0 ... 1, yAxisValues: [0, 0.5, 1], formatYAxis: { $0.formatted(.percent) })
        .frame(height: 220)
        .padding()
}

#Preview("Figure, no trend") {
    SequencePlot(.sampleScatter, yLabel: "Y", xLabel: "Position")
        .padding()
}
