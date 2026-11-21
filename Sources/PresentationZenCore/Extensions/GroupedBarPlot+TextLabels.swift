//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GroupedBarPlot+TextLabels.swift
//  PresentationZenCore
//
//  Created by Rodney Dyer on 2026.11.20.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

public extension GroupedBarPlot where CategoryLabel == Text {

    /// Creates a grouped bar plot that labels each category with its name.
    ///
    /// - Parameters:
    ///   - table: The table to plot; bind categorical `x`, quantitative `y` and `series` roles.
    ///   - categoryColors: Colors by category; categories without one use `defaultColor`.
    ///   - defaultColor: The color of a category with no entry in `categoryColors`.
    ///   - seriesOpacity: The opacity of each series' bars, in series order; later series reuse the last value.
    ///   - showsLegend: Whether to draw the series legend below the chart.
    ///   - formatYAxis: Formats the y-axis values; `nil` uses the default labels.
    init(_ table: DataTable,
         categoryColors: [String: Color] = [:],
         defaultColor: Color = .accentColor,
         seriesOpacity: [Double] = [1, 0.45],
         showsLegend: Bool = true,
         formatYAxis: ((Double) -> String)? = nil) {
        self.init(table,
                  categoryColors: categoryColors,
                  defaultColor: defaultColor,
                  seriesOpacity: seriesOpacity,
                  showsLegend: showsLegend,
                  formatYAxis: formatYAxis) { Text($0) }
    }
}
