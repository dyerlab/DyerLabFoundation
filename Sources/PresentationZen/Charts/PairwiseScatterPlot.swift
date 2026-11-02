//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PairwiseScatterPlot.swift
//  PresentationZen
//
//  One view for every pairwise analysis (isolation by distance, by graph
//  distance, directional graph distance): points per series, each series'
//  fitted line drawn across that series' own x range, and a hover/tap
//  tooltip naming the pair. Series colours are the first slots of a
//  colour-vision-deficiency-checked categorical palette, assigned in fixed
//  order and stepped separately for dark mode; the legend appears only for
//  two or more series, so identity never rests on colour alone.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Charts
import Matrix
import SwiftUI

/// A scatter of pairwise points, one colour per series, with fitted lines.
///
/// Pass any outcome's `scatter` (e.g. an isolation-by-distance outcome):
///
/// ```swift
/// PairwiseScatterPlot(outcome.scatter, summary: "r = 0.42, p = 0.003")
/// ```
public struct PairwiseScatterPlot: View {

    /// The points, series and axis labels to draw.
    public var scatter: PairwiseScatter

    /// Optional text shown above the plot, such as test statistics.
    public var summary: String?

    @Environment(\.colorScheme) private var colorScheme
    @State private var selected: Selection?

    // MARK: - Initialization

    /// Creates a pairwise scatter plot.
    ///
    /// - Parameters:
    ///   - scatter: The points, series and axis labels to draw.
    ///   - summary: Text shown above the plot, or `nil` (default) for none.
    public init(_ scatter: PairwiseScatter, summary: String? = nil) {
        self.scatter = scatter
        self.summary = summary
    }

    // MARK: - Body

    /// The chart.
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let summary {
                Text(summary).font(.caption).foregroundStyle(.secondary)
            }
            chart
        }
    }

    /// The plot itself, below the optional summary.
    private var chart: some View {
        Chart {
            // Points first, then every series' line on top so no line is broken by other points.
            ForEach(scatter.series, id: \.name) { series in
                ForEach(Array(series.points.enumerated()), id: \.offset) { _, point in
                    // A background-coloured halo behind each point keeps overlapping points distinct.
                    PointMark(x: .value(scatter.xLabel, point.x), y: .value(scatter.yLabel, point.y))
                        .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                        .symbolSize(90)
                    PointMark(x: .value(scatter.xLabel, point.x), y: .value(scatter.yLabel, point.y))
                        .foregroundStyle(by: .value("Series", series.name))
                        .symbolSize(48)
                }
            }
            ForEach(scatter.series, id: \.name) { series in
                if let line = series.line, let range = xRange(series.points) {
                    ForEach([range.lowerBound, range.upperBound], id: \.self) { x in
                        LineMark(x: .value(scatter.xLabel, x),
                                 y: .value(scatter.yLabel, line.value(at: x)),
                                 series: .value("Line", series.name))
                        .foregroundStyle(by: .value("Series", series.name))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
            }
            if let selected {
                PointMark(x: .value(scatter.xLabel, selected.point.x), y: .value(scatter.yLabel, selected.point.y))
                    .symbolSize(140)
                    .foregroundStyle(.clear)
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                        tooltip(selected)
                    }
            }
        }
        .chartForegroundStyleScale(domain: scatter.series.map(\.name), range: seriesColors)
        .chartLegend(scatter.series.count > 1 ? .visible : .hidden)
        .chartLegend(position: .top, alignment: .leading)
        .chartYAxis { AxisMarks(position: .leading) }
        .chartXAxisLabel(position: .bottom, alignment: .center) {
            Text(scatter.xLabel).font(.callout).foregroundStyle(.secondary)
        }
        .chartYAxisLabel(position: .leading, alignment: .center) {
            Text(scatter.yLabel).font(.callout).foregroundStyle(.secondary)
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location): selected = nearest(to: location, proxy: proxy, in: geometry)
                        case .ended: selected = nil
                        }
                    }
                    .gesture(SpatialTapGesture().onEnded { tap in
                        selected = nearest(to: tap.location, proxy: proxy, in: geometry)
                    })
            }
        }
    }

    // MARK: - Helpers

    /// A highlighted point and the series it belongs to.
    private struct Selection: Equatable {
        let point: PairwisePoint
        let series: String
    }

    /// The tooltip for a highlighted pair.
    private func tooltip(_ selection: Selection) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(selection.point.from) → \(selection.point.to)").font(.caption.bold())
            if scatter.series.count > 1 {
                Text(selection.series).font(.caption2).foregroundStyle(.secondary)
            }
            Text("\(scatter.xLabel): \(selection.point.x, format: .number.precision(.significantDigits(3)))")
                .font(.caption2)
            Text("\(scatter.yLabel): \(selection.point.y, format: .number.precision(.significantDigits(3)))")
                .font(.caption2)
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
    }

    /// The smallest and largest `x` among `points`, or `nil` if there are none.
    private func xRange(_ points: [PairwisePoint]) -> ClosedRange<Double>? {
        guard let low = points.map(\.x).min(), let high = points.map(\.x).max() else { return nil }
        return low...high
    }

    /// The point nearest `location` within 24 points, or `nil` if none is that close.
    private func nearest(to location: CGPoint, proxy: ChartProxy, in geometry: GeometryProxy) -> Selection? {
        guard let frame = proxy.plotFrame else { return nil }
        let origin = geometry[frame].origin
        let target = CGPoint(x: location.x - origin.x, y: location.y - origin.y)
        var best: (selection: Selection, distance: CGFloat)?
        for series in scatter.series {
            for point in series.points {
                guard let position = proxy.position(for: (x: point.x, y: point.y)) else { continue }
                let distance = hypot(position.x - target.x, position.y - target.y)
                if distance < (best?.distance ?? 24) {
                    best = (Selection(point: point, series: series.name), distance)
                }
            }
        }
        return best?.selection
    }

    /// One colour per series in fixed palette order; series past the eighth
    /// share a neutral grey rather than a generated hue.
    private var seriesColors: [Color] {
        let palette = colorScheme == .dark ? Self.darkPalette : Self.lightPalette
        return scatter.series.indices.map { $0 < palette.count ? palette[$0] : .gray }
    }

    /// Categorical slots for light backgrounds: blue, orange, aqua, yellow,
    /// magenta, green, violet, red.
    private static let lightPalette: [Color] = [0x2A78D6, 0xEB6834, 0x1BAF7A, 0xEDA100,
                                                0xE87BA4, 0x008300, 0x6250D6, 0xE34948].map(color)

    /// The same slots stepped for dark backgrounds.
    private static let darkPalette: [Color] = [0x3987E5, 0xD95926, 0x199E70, 0xC98500,
                                               0xD55181, 0x008300, 0x9085E9, 0xE66767].map(color)

    /// A colour from a `0xRRGGBB` value.
    nonisolated private static func color(_ rgb: Int) -> Color {
        Color(red: Double((rgb >> 16) & 0xFF) / 255,
              green: Double((rgb >> 8) & 0xFF) / 255,
              blue: Double(rgb & 0xFF) / 255)
    }
}

// MARK: - Previews

#Preview("Isolation by Graph Distance (Lophocereus)") {
    PairwiseScatterPlot(.sampleGraphDistance)
        .frame(minWidth: 480, minHeight: 360)
        .padding()
}

#Preview("Directional, Forward vs Reverse (Lophocereus)") {
    PairwiseScatterPlot(.sampleDirectionalGraphDistance, summary: "Forward = northward")
        .frame(minWidth: 480, minHeight: 360)
        .padding()
}
