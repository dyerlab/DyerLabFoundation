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
//  ScatterWithTrendline.swift
//
//
//  Created by Rodney Dyer on 2/10/24.
//

import Charts
import SwiftUI

public struct ScatterPlotWithTrendline: View {
    public var data: [DataPoint]
    public var xLabel: String
    public var yLabel: String
    public var lineSlope: Double
    public var lineIntercept: Double
    public var lineColor: Color
    public var showAnnotations: Bool
    public var showStats: Bool
    public var pointColor: Color
    public var r2: Double?
    public var colors: [String: Color]?

    var trendlinePoints: [DataPoint] {
        return data.trendlinePoints(intercept: lineIntercept,
                                    slope: lineSlope)
    }

    public init(data: [DataPoint], xLabel: String, yLabel: String,
                lineSlope: Double, lineIntercept: Double,
                lineColor: Color = .red,
                showAnnotations: Bool = false,
                showStats: Bool = false,
                pointColor: Color = .primary,
                r2: Double? = nil,
                colors: [String: Color]? = nil) {
        self.data = data
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.lineSlope = lineSlope
        self.lineIntercept = lineIntercept
        self.lineColor = lineColor
        self.showAnnotations = showAnnotations
        self.showStats = showStats
        self.pointColor = pointColor
        self.r2 = r2
        self.colors = colors
    }

    @ChartContentBuilder
    private var chartContent: some ChartContent {
        ForEach(trendlinePoints) {
            LineMark(
                x: .value("X Axis", $0.xValue),
                y: .value("Y Axis", $0.yValue)
            )
            .foregroundStyle(lineColor)
            .lineStyle(.init(dash: [5.0, 3.0]))
        }
        ForEach(data) { item in
            if showAnnotations && !item.label.isEmpty {
                PointMark(
                    x: .value("X Axis", item.xValue),
                    y: .value("Y Axis", item.yValue)
                )
                .foregroundStyle(pointColor)
                .annotation(position: .topTrailing) {
                    Text(item.label)
                        .font(.caption2)
                }
            } else {
                PointMark(
                    x: .value("X Axis", item.xValue),
                    y: .value("Y Axis", item.yValue)
                )
                .foregroundStyle(pointColor)
            }
        }
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            chartView

            if showStats {
                VStack(alignment: .leading, spacing: 2) {
                    Text("β = \(lineSlope, specifier: "%.4f")")
                        .font(.caption)
                    if let r2 {
                        Text("R² = \(r2, specifier: "%.4f")")
                            .font(.caption)
                    }
                }
                .padding(6)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                .padding(8)
            }
        }
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

        if let colors {
            let sorted = colors.sorted(by: { $0.key < $1.key })
            chart.chartForegroundStyleScale(domain: sorted.map(\.key), range: sorted.map(\.value))
        } else {
            chart
        }
    }
}
#if !SPM_BUILD

#Preview {
    ScatterPlotWithTrendline(data: DataPoint.defaultDataPoints,
                             xLabel: "Default X-Axis Label",
                             yLabel: "Default Y-Axis Label",
                             lineSlope: 0.75,
                             lineIntercept: 12.5)
    .padding()
}
#endif
