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
//  BoxPlot.swift
//
//  Created by Rodney Dyer on 4/4/24.
//

import Charts
import SwiftUI

/// A box-style summary plot: one box per category showing ±1σ and ±2σ around
/// the median. Bind a categorical `x` role and a quantitative `y` role; the
/// per-category statistics come from ``DataTable/boxSummary()``.
public struct BoxPlot: View {
    var boxes: [BoxSummary]
    var xLabel: String
    var yLabel: String
    var medianHeight: Double

    public init(_ table: DataTable,
                xLabel: String,
                yLabel: String,
                medianHeight: Double = 0.5) {
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.boxes = table.boxSummary().sorted(by: { $0.category < $1.category })
        self.medianHeight = medianHeight
    }

    public var body: some View {
        Chart(boxes) { item in
            // The ±2σ whisker.
            BarMark(x: .value("Category", item.category),
                    yStart: .value("BoxBottom", item.median - 2.0 * item.sd),
                    yEnd: .value("BoxTop", item.median + 2.0 * item.sd),
                    width: .fixed(3.0))
            .foregroundStyle(Color.secondary.opacity(0.75))

            // The ±1σ box.
            BarMark(x: .value("Category", item.category),
                    yStart: .value("BoxBottom", item.median - item.sd),
                    yEnd: .value("BoxTop", item.median + item.sd))

            // The median band.
            BarMark(x: .value("Category", item.category),
                    yStart: .value("BoxBottom", item.median - medianHeight),
                    yEnd: .value("BoxTop", item.median + medianHeight))
            .foregroundStyle(Color.secondary.opacity(0.75))
        }
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
    BoxPlot(
        DataTable(numbers: ["value": [10, 12, 14, 9, 40, 44, 38, 42, 22, 25, 20, 28]],
                  strings: ["category": ["A", "A", "A", "A", "B", "B", "B", "B", "C", "C", "C", "C"]],
                  roles: [.x: "category", .y: "value"]),
        xLabel: "Categories",
        yLabel: "Values"
    )
    .padding()
}
#endif
