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
//  TimeSeriesPlot.swift
//
//  Created by Rodney Dyer on 2024-04-03.
//

import Charts
import SwiftUI

/// A connected line/point series over time.
///
/// The x-axis kind is taken from the bound `x` column: a date column renders a
/// temporal axis, a numeric column renders an ordinal one. Binding a `series`
/// role with two or more groups colors the points and shows a legend.
public struct TimeSeriesPlot: View {
    public var table: DataTable
    public var yLabel: String
    public var xLabel: String
    public var soloColor: Color
    public var lineColor: Color

    public init(_ table: DataTable,
                yLabel: String,
                xLabel: String = "",
                ptColor: Color = .orange,
                lineColor: Color = .gray) {
        self.table = table
        self.yLabel = yLabel
        self.soloColor = ptColor
        self.lineColor = lineColor
        if xLabel.isEmpty {
            self.xLabel = table.xKind == .date ? "Date" : "Ordinal"
        } else {
            self.xLabel = xLabel
        }
    }

    private var grouped: Bool { table.seriesValues.count >= 2 }

    // MARK: - Per-kind content (no `if/else` at ChartContent level)

    @ChartContentBuilder
    private var dateContent: some ChartContent {
        ForEach(table.plotRows) { row in
            if let date = row.x.dateValue {
                LineMark(x: .value("X Value", date),
                         y: .value(yLabel, row.y))
                .foregroundStyle(lineColor)
                .lineStyle(.init(dash: [5.0, 5.0]))
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
            .lineStyle(.init(dash: [5.0, 5.0]))
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
        .frame(minHeight: 300)
    }

    /// Applies the shared styling/labels to either chart variant.
    private func styled<Content: View>(_ chart: Content) -> some View {
        chart
            .seriesStyle(hasSeries: grouped, soloColor: soloColor)
            .chartXAxisLabel(position: .bottom, alignment: .center) {
                Text(xLabel).font(.headline)
            }
            .chartYAxisLabel(position: .trailing, alignment: .center) {
                Text(yLabel).font(.title3)
            }
    }
}
#if !SPM_BUILD

#Preview("Date") {
    TimeSeriesPlot(.sampleTemporal, yLabel: "Y-Axis Data")
        .padding()
}

#Preview("Ordinal") {
    TimeSeriesPlot(.sampleScatter, yLabel: "Y-Axis Data")
        .padding()
}
#endif
