//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Histogram.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2024.03.29.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Charts
import Matrix
import SwiftUI

/// A histogram over raw values, rendered as a smoothed area, bars, a kernel density
/// curve, or a descriptive-statistics table.
///
/// Pass the raw (unbinned) data; bind the value column to `y` — e.g.
/// `Histogram(nullDistributionTable(result), bins: 20)`. `Histogram` bins and
/// summarizes internally, via `DataTable/histogram(of:bins:)` and
/// `DataTable/summary(of:)`, so callers never pre-shape the table themselves.
public struct Histogram: View {

    /// How the data is rendered.
    public enum Style: Sendable {
        /// A `catmullRom`-interpolated area across bin centers.
        case continuous
        /// One bar per bin, centered on the bin's midpoint at a fixed width.
        case discrete
        /// One bar per bin, spanning its true lower and upper edges.
        case binned
        /// A Gaussian kernel density curve of the values themselves, rather than a smoothing of their bin counts.
        case density
        /// A table of descriptive statistics (count, quartiles, mean, extrema).
        case tabular
    }

    /// The raw (unbinned) data; bind the value column to `y`.
    public var table: DataTable
    /// The column to bin/summarize; defaults to the column bound to `y`.
    public var column: String?
    /// The number of equal-width bins, for ``Style/continuous``, ``Style/discrete`` and ``Style/binned``.
    public var bins: Int
    /// The x-axis title.
    public var xLabel: String
    /// The y-axis title.
    public var yLabel: String
    /// How the values are drawn; ``Style/continuous`` by default.
    public var style: Style
    /// The number of decimal places shown in ``Style/tabular``'s value column.
    public var digits: Int

    /// The share of a ``Style/binned`` bar's width left as a gap on either side, so bars read separately.
    private static let barInset = 0.02

    private let curGradient = LinearGradient(
        gradient: Gradient(colors: [Color(.blue).opacity(0.9), Color(.blue).opacity(0.5)]),
        startPoint: .top,
        endPoint: .bottom
    )

    /// Creates a histogram.
    ///
    /// - Parameters:
    ///   - table: The raw (unbinned) data; bind the value column to `y`.
    ///   - column: The column to bin/summarize; defaults to the column bound to `y`.
    ///   - bins: The number of equal-width bins, for ``Style/continuous``, ``Style/discrete`` and ``Style/binned``.
    ///   - xLabel: The x-axis title.
    ///   - yLabel: The y-axis title.
    ///   - style: How the values are drawn. Defaults to ``Style/continuous``.
    ///   - digits: The number of decimal places shown in ``Style/tabular``'s value column.
    public init(_ table: DataTable,
                column: String? = nil,
                bins: Int = 10,
                xLabel: String = "Values",
                yLabel: String = "Count",
                style: Style = .continuous,
                digits: Int = 3) {
        self.table = table
        self.column = column
        self.bins = bins
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.style = style
        self.digits = digits
    }

    public var body: some View {
        content
    }

    /// Branches at the View level (not inside a chart-content builder) so each
    /// side is a plain `Chart`, matching the `_ConditionalContent` constraint
    /// documented in `ChartSupport.swift`.
    @ViewBuilder
    private var content: some View {
        switch style {
        case .continuous:
            axisTitles(Chart(table.histogram(of: column, bins: bins).plotRows) { row in
                AreaMark(x: .value("X-value", row.xDouble),
                         y: .value("Y-value", row.y))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(curGradient)
            })
        case .discrete:
            axisTitles(Chart(table.histogram(of: column, bins: bins).plotRows) { row in
                BarMark(x: .value("X-value", row.xDouble),
                        y: .value("Y-value", row.y))
                .foregroundStyle(curGradient)
            })
        case .binned:
            axisTitles(Chart(values.histogram(bins: bins), id: \.lower) { bin in
                let edges = Self.edges(of: bin)
                RectangleMark(xStart: .value("Lower", edges.lowerBound),
                              xEnd: .value("Upper", edges.upperBound),
                              yStart: .value("Base", 0),
                              yEnd: .value("Count", bin.count))
                    .foregroundStyle(.blue)
            }
            .chartXScale(domain: .automatic(includesZero: false)))
        case .density:
            axisTitles(Chart(KernelDensity(values)) { point in
                AreaMark(x: .value("Value", point.x), y: .value("Density", point.density))
                    .foregroundStyle(.blue.opacity(0.3))
                LineMark(x: .value("Value", point.x), y: .value("Density", point.density))
                    .foregroundStyle(.blue)
            }
            .chartXScale(domain: .automatic(includesZero: false)))
        case .tabular:
            DataTableView(table.summary(of: column), formatString: "%.\(digits)f", inScrollView: false)
        }
    }

    /// The values being drawn, without any missing ones.
    private var values: Vector {
        table.column(column ?? table.column(for: .y) ?? "")
    }

    private func axisTitles(_ chart: some View) -> some View {
        chart
            .chartXAxisLabel(position: .bottom, alignment: .center) {
                Text(xLabel).font(.title3)
            }
            .chartYAxisLabel(position: .trailing, alignment: .center) {
                Text(yLabel).font(.title3)
            }
    }

    /// Finds where to draw a ``Style/binned`` bar.
    ///
    /// When every value is the same the single bin has no width, so it is given one to stay visible.
    ///
    /// - Parameter bin: The histogram bin.
    /// - Returns: The bar's horizontal extent.
    private static func edges(of bin: Vector.Bin) -> ClosedRange<Double> {
        let width = bin.upper - bin.lower
        guard width > 0 else { return (bin.center - 0.5)...(bin.center + 0.5) }
        return (bin.lower + barInset * width)...(bin.upper - barInset * width)
    }
}

// MARK: - Previews

#Preview {
    VStack(spacing: 25) {
        Histogram(.sampleValues, bins: 8, xLabel: "Raw Data", yLabel: "Counts", style: .continuous)
            .frame(minHeight: 350)

        Histogram(.sampleValues, bins: 8, xLabel: "Raw Data", yLabel: "Counts", style: .discrete)
            .frame(minHeight: 350)

        Histogram(.sampleValues, bins: 8, xLabel: "Raw Data", yLabel: "Counts", style: .binned)
            .frame(minHeight: 350)

        Histogram(.sampleValues, xLabel: "Raw Data", yLabel: "Density", style: .density)
            .frame(minHeight: 350)

        Histogram(.sampleValues, xLabel: "Raw Data", yLabel: "Counts", style: .tabular)
            .frame(minHeight: 350)
    }
    .padding()
}
