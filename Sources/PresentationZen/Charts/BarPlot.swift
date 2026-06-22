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
//
//  Created by Rodney Dyer on 2/10/24.
//

import Charts
import SwiftUI

public struct BarPlot: View {
    public var data: [DataPoint]
    public var xLabel: String
    public var yLabel: String
    public var showLabel: Bool
    public var showGroups: Bool
    public var showValues: Bool
    public var valueFormat: String
    public var rotateLabels: Bool

    public init(data: [DataPoint],
                xLabel: String = "Categories", yLabel: String = "Value",
                showLabel: Bool = false,
                showGroups: Bool = false,
                showValues: Bool = false,
                valueFormat: String = "%.0f",
                rotateLabels: Bool = false) {
        self.data = data
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.showLabel = showLabel
        self.showGroups = showGroups
        self.showValues = showValues
        self.valueFormat = valueFormat
        self.rotateLabels = rotateLabels
    }


    public var chart: some View {
        Chart {
            ForEach(data, id: \.self) { item in
                if showLabel {
                    if showGroups {
                        BarMark(x: .value("Category", item.category),
                                y: .value("Value", item.yValue))
                        .foregroundStyle(by: .value("Group", item.grouping))
                        .annotation {
                            Text("\(item.label)")
                                .font(.footnote)
                        }
                    } else {
                        BarMark(x: .value("Category", item.category),
                                y: .value("Value", item.yValue))
                        .annotation {
                            Text("\(item.label)")
                                .font(.footnote)
                        }
                    }
                } else if showValues {
                    if showGroups {
                        BarMark(x: .value("Category", item.category),
                                y: .value("Value", item.yValue))
                        .foregroundStyle(by: .value("Group", item.grouping))
                        .annotation(position: .top) {
                            Text(String(format: valueFormat, item.yValue))
                                .font(.caption2)
                        }
                    } else {
                        BarMark(x: .value("Category", item.category),
                                y: .value("Value", item.yValue))
                        .annotation(position: .top) {
                            Text(String(format: valueFormat, item.yValue))
                                .font(.caption2)
                        }
                    }
                } else {
                    if showGroups {
                        BarMark(x: .value("Category", item.category),
                                y: .value("Value", item.yValue))
                        .foregroundStyle(by: .value("Group", item.grouping))
                    } else {
                        BarMark(x: .value("Category", item.category),
                                y: .value("Value", item.yValue))
                    }
                }
            }
        }
        .chartXAxisLabel(position: .bottom,
                         alignment: .center,
                         content: {
            Text(xLabel)
                .font(.title3)
        })
        .chartYAxisLabel(position: .trailing,
                         alignment: .center,
                         content: {
            Text(yLabel)
                .font(.title3)
        })
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


    public var body: some View {
        if self.showGroups {
            self.chart
                .chartLegend(position: .top)
        } else {
            self.chart
        }
    }
}
#if !SPM_BUILD

#Preview {
    VStack(spacing: 25) {
        BarPlot(data: DataPoint.defaultDataPoints,
                xLabel: "Default Categories",
                yLabel: "Random Values")

        BarPlot(data: DataPoint.defaultDataPoints,
                xLabel: "Default Categories",
                yLabel: "Random Values",
                showLabel: true)

        BarPlot(data: DataPoint.defaultDataPoints,
                xLabel: "Default Categories",
                yLabel: "Random Values",
                showValues: true,
                rotateLabels: true)

        BarPlot(data: DataPoint.defaultDataPoints,
                xLabel: "Default Categories",
                yLabel: "Random Values",
                showGroups: true)
    }
    .frame(minHeight: 800)
    .padding()
}
#endif
