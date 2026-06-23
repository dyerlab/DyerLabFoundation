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
//  TemporalScatterPlot.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026-02-16.
//

import Charts
import SwiftUI

/// A scatter plot with a temporal (Date) x-axis and an optional auto-computed
/// linear regression trendline.
///
/// Bind a date `x` role and a quantitative `y` role; bind a `label` role to
/// annotate points.
public struct TemporalScatterPlot: View {
    public var table: DataTable
    public var xLabel: String
    public var yLabel: String
    public var pointColor: Color
    public var lineColor: Color
    public var showRegression: Bool
    public var showStats: Bool
    public var showAnnotations: Bool

    public init(_ table: DataTable,
                xLabel: String = "Date",
                yLabel: String,
                pointColor: Color = .green,
                lineColor: Color = .red,
                showRegression: Bool = true,
                showStats: Bool = true,
                showAnnotations: Bool = true) {
        self.table = table
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.pointColor = pointColor
        self.lineColor = lineColor
        self.showRegression = showRegression
        self.showStats = showStats
        self.showAnnotations = showAnnotations
    }

    private var regression: RegressionResult? {
        showRegression ? dateRegression(table) : nil
    }

    @ChartContentBuilder
    private var chartContent: some ChartContent {
        ForEach(table.plotRows) { row in
            if let date = row.x.dateValue {
                PointMark(x: .value(xLabel, date),
                          y: .value(yLabel, row.y))
                .foregroundStyle(pointColor)
                .annotation(position: .topTrailing) {
                    if showAnnotations, let label = row.label, !label.isEmpty {
                        Text(label).font(.caption2)
                    }
                }
            }
        }

        if let regression, !regression.isEmpty {
            ForEach(regression.fitted) { row in
                if let date = row.x.dateValue {
                    LineMark(x: .value(xLabel, date),
                             y: .value(yLabel, row.y))
                    .foregroundStyle(lineColor)
                    .lineStyle(.init(dash: [5.0, 3.0]))
                }
            }
        }
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Chart { chartContent }
                .chartXAxisLabel(position: .bottom, alignment: .center) {
                    Text(xLabel).font(.title3)
                }
                .chartYAxisLabel(position: .trailing, alignment: .center) {
                    Text(yLabel).font(.title3)
                }

            if showStats, let regression {
                VStack(alignment: .leading, spacing: 2) {
                    Text("β = \(regression.slope, specifier: "%.4f")")
                        .font(.caption)
                    Text("R² = \(regression.r2, specifier: "%.4f")")
                        .font(.caption)
                }
                .padding(6)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                .padding(8)
            }
        }
    }
}
#if !SPM_BUILD

#Preview {
    TemporalScatterPlot(.sampleTemporal, yLabel: "Score")
        .frame(height: 300)
        .padding()
}
#endif
