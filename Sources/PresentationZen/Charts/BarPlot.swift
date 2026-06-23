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
//  BarPlot.swift
//
//  Created by Rodney Dyer on 2/10/24.
//

import Charts
import SwiftUI

/// A categorical bar chart. Bind a categorical `x` role and a quantitative `y`
/// role; a `series` role splits bars by color and a `label` role annotates
/// them.
public struct BarPlot: View {
    public var table: DataTable
    public var xLabel: String
    public var yLabel: String
    public var showLabel: Bool
    public var showValues: Bool
    public var valueFormat: String
    public var rotateLabels: Bool
    public var barColor: Color

    public init(_ table: DataTable,
                xLabel: String = "Categories",
                yLabel: String = "Value",
                showLabel: Bool = false,
                showValues: Bool = false,
                valueFormat: String = "%.0f",
                rotateLabels: Bool = false,
                barColor: Color = .blue) {
        self.table = table
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.showLabel = showLabel
        self.showValues = showValues
        self.valueFormat = valueFormat
        self.rotateLabels = rotateLabels
        self.barColor = barColor
    }

    /// Renders the x value as a category string regardless of column kind.
    private func category(for row: PlotRow) -> String {
        row.x.stringValue ?? String(format: "%.0f", row.xDouble)
    }

    public var body: some View {
        Chart(table.plotRows) { row in
            BarMark(x: .value("Category", category(for: row)),
                    y: .value("Value", row.y))
            .foregroundStyle(by: .value("Group", row.series ?? ""))
            .annotation(position: .top) {
                if showLabel, let label = row.label, !label.isEmpty {
                    Text(label).font(.footnote)
                } else if showValues {
                    Text(String(format: valueFormat, row.y)).font(.caption2)
                }
            }
        }
        .seriesStyle(hasSeries: table.column(for: .series) != nil, soloColor: barColor)
        .chartXAxisLabel(position: .bottom, alignment: .center) {
            Text(xLabel).font(.title3)
        }
        .chartYAxisLabel(position: .trailing, alignment: .center) {
            Text(yLabel).font(.title3)
        }
        .chartXAxis {
            if rotateLabels {
                AxisMarks { _ in
                    AxisValueLabel(orientation: .verticalReversed)
                    AxisGridLine()
                    AxisTick()
                }
            } else {
                AxisMarks()
            }
        }
    }
}
#if !SPM_BUILD

#Preview {
    VStack(spacing: 25) {
        BarPlot(.sampleBars, xLabel: "Categories", yLabel: "Value", showValues: true)

        BarPlot(.sampleBars.series("group"), xLabel: "Categories", yLabel: "Value")
    }
    .frame(minHeight: 600)
    .padding()
}
#endif
