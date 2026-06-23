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
//  Numberline.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 11/1/24.
//

import SwiftUI
import Charts

/// A one-dimensional strip plotting the `y` values along a single axis,
/// colored by the optional `series` role.
public struct NumberLine: View {
    var table: DataTable
    var minX: Double
    var maxX: Double

    public init(_ table: DataTable, minX: Double = -1.0, maxX: Double = 1.0) {
        self.table = table
        self.minX = (minX * 1.1)
        self.maxX = (maxX * 1.1)
    }

    public var body: some View {
        Chart(table.plotRows) { row in
            PointMark(x: .value("Amount", row.y),
                      y: .value("Period", 0.0))
            .foregroundStyle(by: .value("Group", row.series ?? ""))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 25)
        .fixedSize(horizontal: false, vertical: true)
        .chartXScale(domain: minX...maxX)
        .chartLegend(.hidden)
    }
}
#if !SPM_BUILD

#Preview {
    NumberLine(
        DataTable(numbers: ["value": (0 ..< 7).map { _ in Double.random(in: -1.0...1.0) }],
                  strings: ["category": ["First", "Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh"]],
                  roles: [.y: "value", .series: "category"])
    )
    .padding()
}
#endif
