//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GroupedBarPlotTests.swift
//  PresentationZenTests
//
//  Created by Rodney Dyer on 2026.11.20.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import PresentationZenCore

@MainActor
struct GroupedBarPlotTests {

    @Test("series keep the order they first appear, not alphabetical order")
    func seriesOrder() {
        let table = DataTable(numbers: ["v": [1, 2, 3, 4]],
                              strings: ["c": ["A", "A", "B", "B"],
                                        "s": ["Production", "Cost", "Production", "Cost"]],
                              roles: [.x: "c", .y: "v", .series: "s"])
        #expect(GroupedBarPlot(table).seriesOrder == ["Production", "Cost"])
    }
}
