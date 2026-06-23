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
//  PiePlot.swift
//
//  Created by Rodney Dyer on 2/17/24.
//

import SwiftUI
import Charts

/// A pie/donut chart. The `y` role is each slice's magnitude; the `label` role
/// names the slice (and drives the color scale).
public struct PiePlot: View {
    public var table: DataTable
    public var title: String
    public var innerRadius: Double
    public var showLegend: Bool
    public var showValues: Bool
    public var valueFormat: String
    public var colors: [String: Color]?

    public init(_ table: DataTable,
                title: String = "",
                innerRadius: Double = 0.25,
                showLegend: Bool = false,
                showValues: Bool = false,
                valueFormat: String = "%.1f",
                colors: [String: Color]? = nil) {
        self.table = table
        self.title = title
        self.innerRadius = innerRadius
        self.showLegend = showLegend
        self.showValues = showValues
        self.valueFormat = valueFormat
        self.colors = colors
    }

    public var body: some View {
        ZStack {
            chartView
            Text("\(title)")
                .font(.title2)
        }
    }

    @ViewBuilder
    private var chartView: some View {
        let chart = Chart(table.plotRows) { row in
            SectorMark(angle: .value(Text(verbatim: row.label ?? ""), row.y),
                       innerRadius: .ratio(innerRadius),
                       angularInset: 1.5)
            .cornerRadius(3)
            .foregroundStyle(by: .value(Text(verbatim: row.label ?? ""), row.label ?? ""))
            .annotation(position: .overlay) {
                if row.y != 0.0 {
                    if showValues {
                        Text(String(format: valueFormat, row.y))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(verbatim: row.label ?? "")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartLegend(showLegend ? .visible : .hidden)

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
    PiePlot(DataTable(numbers: ["count": [30, 20, 15, 35]],
                      strings: ["name": ["Alpha", "Beta", "Gamma", "Delta"]],
                      roles: [.y: "count", .label: "name"]),
            title: "Shares",
            showLegend: true,
            showValues: true,
            valueFormat: "%.0f")
    .padding()
}
#endif
