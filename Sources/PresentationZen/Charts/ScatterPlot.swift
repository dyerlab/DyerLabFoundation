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
//  ScatterPlot.swift
//
//  Created by Rodney Dyer on 2/10/24.
//

import Charts
import SwiftUI

/// A quantitative x/y scatter plot.
///
/// Bind the `x` and `y` roles on the ``DataTable``. Binding a `series` role
/// colors points by group and shows a legend; binding a `label` role and
/// setting `showLabel` annotates each point.
public struct ScatterPlot: View {
    public var table: DataTable
    public var xLabel: String
    public var yLabel: String
    public var showLabel: Bool
    public var pointColor: Color

    /// Creates a scatter plot.
    ///
    /// - Parameters:
    ///   - table: The table to plot; bind quantitative `x`/`y` roles (and optionally
    ///     `series`/`label`).
    ///   - xLabel: The x-axis title.
    ///   - yLabel: The y-axis title.
    ///   - showLabel: Whether to annotate each point with its `label`-role value.
    ///   - pointColor: The point color when no `series` role is bound.
    public init(_ table: DataTable,
                xLabel: String,
                yLabel: String,
                showLabel: Bool = false,
                pointColor: Color = .blue) {
        self.table = table
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.showLabel = showLabel
        self.pointColor = pointColor
    }

    public var body: some View {
        Chart(table.plotRows) { row in
            PointMark(x: .value("X Value", row.xDouble),
                      y: .value("Y Value", row.y))
            .foregroundStyle(by: .value("Group", row.series ?? ""))
            .annotation {
                if showLabel, let label = row.label, !label.isEmpty {
                    Text(label).font(.footnote)
                }
            }
        }
        .seriesStyle(hasSeries: table.column(for: .series) != nil, soloColor: pointColor)
        .chartXAxisLabel(position: .bottom, alignment: .center) {
            Text(xLabel).font(.title3)
        }
        .chartYAxisLabel(position: .trailing, alignment: .center) {
            Text(yLabel).font(.title3)
        }
    }
}
#if !SPM_BUILD

#Preview {
    ScrollView {
        VStack(spacing: 25) {
            ScatterPlot(.sampleScatter, xLabel: "X-Axis", yLabel: "Y-Axis")

            ScatterPlot(.sampleScatter.label("label"),
                        xLabel: "X-Axis", yLabel: "Y-Axis", showLabel: true)

            ScatterPlot(.sampleScatter.series("group"),
                        xLabel: "X-Axis", yLabel: "Y-Axis")
        }
        .frame(minHeight: 700)
        .padding()
    }
}
#endif
