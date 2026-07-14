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
//  DistributionPlot.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026-02-16.
//

import Charts
import SwiftUI

/// An area chart of a frequency distribution with an optional reference line.
///
/// Pass a table whose `x` role is the (quantitative) domain value and `y` role
/// is the frequency/count.
public struct DistributionPlot: View {
    public var table: DataTable
    public var xLabel: String
    public var yLabel: String
    public var fillColor: Color
    public var referenceLine: Double?
    public var referenceLabel: String?
    public var referenceColor: Color
    public var xDomain: ClosedRange<Double>?

    /// Creates a distribution plot.
    ///
    /// - Parameters:
    ///   - table: The table to plot; bind the quantitative domain value to `x` and the
    ///     frequency/count to `y` (see `DataTable(nullDistribution:)`/`histogram(of:bins:)`).
    ///   - xLabel: The x-axis title.
    ///   - yLabel: The y-axis title.
    ///   - fillColor: The area fill color.
    ///   - referenceLine: An optional x-position (e.g. an observed statistic) to mark with a
    ///     dashed vertical rule.
    ///   - referenceLabel: An optional label drawn above `referenceLine`; ignored if
    ///     `referenceLine` is `nil`.
    ///   - referenceColor: The reference line/label color.
    ///   - xDomain: An optional fixed x-axis range; when `nil`, the chart scales to the data.
    public init(_ table: DataTable,
                xLabel: String = "Value",
                yLabel: String = "Frequency",
                fillColor: Color = .blue.opacity(0.3),
                referenceLine: Double? = nil,
                referenceLabel: String? = nil,
                referenceColor: Color = .red,
                xDomain: ClosedRange<Double>? = nil) {
        self.table = table
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.fillColor = fillColor
        self.referenceLine = referenceLine
        self.referenceLabel = referenceLabel
        self.referenceColor = referenceColor
        self.xDomain = xDomain
    }

    /// The resolved rows padded with zero endpoints so the area meets the axis.
    private var paddedRows: [PlotRow] {
        let rows = table.plotRows
        guard let first = rows.first, let last = rows.last else { return rows }
        var result = [PlotRow]()
        result.append(PlotRow(id: -1, x: .number(first.xDouble - 0.5), y: 0))
        result.append(contentsOf: rows)
        result.append(PlotRow(id: -2, x: .number(last.xDouble + 0.5), y: 0))
        return result
    }

    @ChartContentBuilder
    private var chartContent: some ChartContent {
        ForEach(paddedRows) { row in
            AreaMark(x: .value(xLabel, row.xDouble),
                     y: .value(yLabel, row.y))
            .foregroundStyle(fillColor)
            .interpolationMethod(.catmullRom)
        }

        if let referenceLine {
            RuleMark(x: .value("Reference", referenceLine))
                .foregroundStyle(referenceColor)
                .lineStyle(.init(dash: [5.0, 3.0]))
                .annotation(position: .top, alignment: .trailing) {
                    if let referenceLabel {
                        Text(referenceLabel)
                            .font(.caption)
                            .foregroundStyle(referenceColor)
                    }
                }
        }
    }

    public var body: some View {
        chartView
    }

    @ViewBuilder
    private var chartView: some View {
        let chart = Chart { chartContent }
            .chartXAxisLabel(position: .bottom, alignment: .center) {
                Text(xLabel).font(.title3)
            }
            .chartYAxisLabel(position: .trailing, alignment: .center) {
                Text(yLabel).font(.title3)
            }

        if let xDomain {
            chart.chartXScale(domain: xDomain)
        } else {
            chart
        }
    }
}
#if !SPM_BUILD

#Preview {
    DistributionPlot(
        DataTable(numbers: ["score": [1, 2, 3, 4, 5],
                            "count": [2, 5, 12, 8, 3]],
                  roles: [.x: "score", .y: "count"]),
        xLabel: "Score",
        yLabel: "Count",
        referenceLine: 3.2,
        referenceLabel: "Mean: 3.2",
        xDomain: 0.5...5.5
    )
    .frame(height: 250)
    .padding()
}
#endif
