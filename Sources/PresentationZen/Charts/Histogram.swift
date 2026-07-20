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
//  Histogram.swift
//
//  Created by Rodney Dyer on 3/29/24.
//

import Charts
import SwiftUI

/// A histogram over raw values, rendered as a smoothed area, discrete bars, or
/// a descriptive-statistics table.
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
        /// One bar per bin.
        case discrete
        /// A table of descriptive statistics (count, quartiles, mean, extrema).
        case tabular
    }

    public var table: DataTable
    public var column: String?
    public var bins: Int
    public var xLabel: String
    public var yLabel: String
    public var style: Style
    public var digits: Int

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
    ///   - bins: The number of equal-width bins, for ``Style/continuous``/``Style/discrete``.
    ///   - xLabel: The x-axis title.
    ///   - yLabel: The y-axis title.
    ///   - style: Whether to draw a smoothed area (``Style/continuous``), discrete
    ///     bars (``Style/discrete``), or a statistics table (``Style/tabular``). Defaults
    ///     to ``Style/continuous``.
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
            Chart(table.histogram(of: column, bins: bins).plotRows) { row in
                AreaMark(x: .value("X-value", row.xDouble),
                         y: .value("Y-value", row.y))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(curGradient)
            }
            .chartXAxisLabel(position: .bottom, alignment: .center) {
                Text(xLabel).font(.title3)
            }
            .chartYAxisLabel(position: .trailing, alignment: .center) {
                Text(yLabel).font(.title3)
            }
        case .discrete:
            Chart(table.histogram(of: column, bins: bins).plotRows) { row in
                BarMark(x: .value("X-value", row.xDouble),
                        y: .value("Y-value", row.y))
                .foregroundStyle(curGradient)
            }
            .chartXAxisLabel(position: .bottom, alignment: .center) {
                Text(xLabel).font(.title3)
            }
            .chartYAxisLabel(position: .trailing, alignment: .center) {
                Text(yLabel).font(.title3)
            }
        case .tabular:
            DataTableView(table.summary(of: column), formatString: "%.\(digits)f", inScrollView: false)
        }
    }
}



#Preview {
    VStack(spacing: 25) {
        Histogram(.sampleValues, bins: 8, xLabel: "Raw Data", yLabel: "Counts", style: .continuous)
            .frame(minHeight: 350)

        Histogram(.sampleValues, bins: 8, xLabel: "Raw Data", yLabel: "Counts", style: .discrete)
            .frame(minHeight: 350)

        Histogram(.sampleValues, xLabel: "Raw Data", yLabel: "Counts", style: .tabular)
            .frame(minHeight: 350)
    }
    .padding()
}
