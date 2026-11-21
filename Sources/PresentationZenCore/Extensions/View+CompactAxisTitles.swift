//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  View+CompactAxisTitles.swift
//  PresentationZenCore
//
//  An empty axis title still takes a line in Swift Charts, so compact charts add a title only when there is one.
//
//  Created by Rodney Dyer on 2026.11.20.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Charts
import SwiftUI

extension View {

    /// Adds small axis titles for ``PlotStyle/compact`` charts, leaving out any that are empty.
    ///
    /// - Parameters:
    ///   - x: The x-axis title, or empty for none.
    ///   - y: The y-axis title, or empty for none.
    /// - Returns: The chart with the titles it has.
    @ViewBuilder
    func compactAxisTitles(x: String, y: String) -> some View {
        switch (x.isEmpty, y.isEmpty) {
        case (true, true):
            self
        case (false, true):
            self.chartXAxisLabel(x, alignment: .center)
        case (true, false):
            self.chartYAxisLabel(y)
        case (false, false):
            self.chartXAxisLabel(x, alignment: .center).chartYAxisLabel(y)
        }
    }
}
