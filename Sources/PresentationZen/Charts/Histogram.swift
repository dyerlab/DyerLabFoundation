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
//  Histogram.swift
//
//  Created by Rodney Dyer on 3/29/24.
//

import Charts
import SwiftUI

/// An area-style histogram.
///
/// Pass a table whose `x` role is a bin center and `y` role is a count — e.g.
/// `Histogram(raw.histogram(of: "value", bins: 12))`.
public struct Histogram: View {
    public var table: DataTable
    public var xLabel: String
    public var yLabel: String

    private let curGradient = LinearGradient(
        gradient: Gradient(colors: [Color(.blue).opacity(0.9), Color(.blue).opacity(0.5)]),
        startPoint: .top,
        endPoint: .bottom
    )

    /// Creates a histogram.
    ///
    /// - Parameters:
    ///   - table: A binned table; bind the bin center to `x` and its count to `y`
    ///     (see `DataTable/histogram(of:bins:)`).
    ///   - xLabel: The x-axis title.
    ///   - yLabel: The y-axis title.
    public init(_ table: DataTable, xLabel: String = "Values", yLabel: String = "Count") {
        self.table = table
        self.xLabel = xLabel
        self.yLabel = yLabel
    }

    public var body: some View {
        Chart(table.plotRows) { row in
            AreaMark(x: .value("X-value", row.xDouble),
                     y: .value("Y-value", row.y))
            .interpolationMethod(.catmullRom)
            .foregroundStyle(curGradient)
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
    Histogram(DataTable.sampleValues.histogram(of: "value", bins: 8),
              xLabel: "Raw Data",
              yLabel: "Counts")
    .padding()
}
#endif
