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
//  ChartSupport.swift
//
//  Shared helpers for the chart layer. The `seriesStyle` modifier keeps
//  color/legend branching at the View level so the `Chart { }` content
//  builders stay free of `_ConditionalContent`, which is required on the
//  macOS 14 / iOS 17 deployment floor.
//

import SwiftUI
import Charts

public extension PlotRow {
    /// The x position as a `Double` for quantitative axes; `.nan` when the x
    /// value is not numeric.
    var xDouble: Double { x.doubleValue ?? .nan }
}

extension View {

    /// Applies color/legend treatment based on whether a series role is bound.
    ///
    /// - When a series is bound, the automatic color scale and a top legend
    ///   are used.
    /// - Otherwise every mark resolves to `soloColor` and the legend is hidden.
    ///
    /// The `if/else` here is at the View level (not inside a chart-content
    /// builder), so it produces a `View`'s `_ConditionalContent` — which is
    /// available on the deployment floor — not a `ChartContent` one.
    @ViewBuilder
    func seriesStyle(hasSeries: Bool, soloColor: Color) -> some View {
        if hasSeries {
            self.chartLegend(position: .top)
        } else {
            self
                .chartForegroundStyleScale(domain: [""], range: [soloColor])
                .chartLegend(.hidden)
        }
    }
}
