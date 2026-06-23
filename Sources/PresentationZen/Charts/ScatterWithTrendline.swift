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
//  Created by Rodney Dyer on 2/10/24.
//

import Charts
import SwiftUI

/// A quantitative scatter plot overlaid with a fitted trendline.
///
/// The line endpoints are derived from the `x` role's range via
/// ``DataTable/trendline(intercept:slope:)``.
public struct ScatterPlotWithTrendline: View {
    public var table: DataTable
    public var xLabel: String
    public var yLabel: String
    public var lineSlope: Double
    public var lineIntercept: Double
    public var lineColor: Color
    public var showAnnotations: Bool
    public var showStats: Bool
    public var pointColor: Color
    public var r2: Double?

    public init(_ table: DataTable,
                xLabel: String,
                yLabel: String,
                lineSlope: Double,
                lineIntercept: Double,
                lineColor: Color = .red,
                showAnnotations: Bool = false,
                showStats: Bool = false,
                pointColor: Color = .primary,
                r2: Double? = nil) {
        self.table = table
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.lineSlope = lineSlope
        self.lineIntercept = lineIntercept
        self.lineColor = lineColor
        self.showAnnotations = showAnnotations
        self.showStats = showStats
        self.pointColor = pointColor
        self.r2 = r2
    }

    private var trendRows: [PlotRow] {
        table.trendline(intercept: lineIntercept, slope: lineSlope).plotRows
    }

    @ChartContentBuilder
    private var chartContent: some ChartContent {
        ForEach(trendRows) { row in
            LineMark(x: .value("X Axis", row.xDouble),
                     y: .value("Y Axis", row.y))
            .foregroundStyle(lineColor)
            .lineStyle(.init(dash: [5.0, 3.0]))
        }
        ForEach(table.plotRows) { row in
            PointMark(x: .value("X Axis", row.xDouble),
                      y: .value("Y Axis", row.y))
            .foregroundStyle(pointColor)
            .annotation(position: .topTrailing) {
                if showAnnotations, let label = row.label, !label.isEmpty {
                    Text(label).font(.caption2)
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
}
#if !SPM_BUILD

#Preview {
    ScatterPlotWithTrendline(.sampleScatter,
                             xLabel: "X-Axis",
                             yLabel: "Y-Axis",
                             lineSlope: 5.0,
                             lineIntercept: 12.5,
                             showStats: true,
                             r2: 0.78)
    .padding()
}
#endif
