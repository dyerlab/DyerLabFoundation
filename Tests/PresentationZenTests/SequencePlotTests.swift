//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  SequencePlotTests.swift
//  PresentationZenTests
//
//  Created by Rodney Dyer on 2026.11.27.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import PresentationZenCore

@MainActor
struct SequencePlotTests {

    private func table(_ count: Int) -> DataTable {
        let positions = (1 ... count).map(Double.init)
        return DataTable(numbers: ["n": positions, "v": positions], roles: [.x: "n", .y: "v"])
    }

    @Test("the axis spans every position with half a step to spare, and reaches bands and markers")
    func domain() {
        #expect(SequencePlot(table(4)).xDomain == 0.5 ... 4.5)
        let wider = SequencePlot(table(4), bands: [.covering(1, through: 6)], markers: [.after(6)])
        #expect(wider.xDomain == 0.5 ... 6.5)
        #expect(SequencePlot(DataTable(numbers: [:])).xDomain == 0.5 ... 1.5)
    }

    @Test("ticks are whole positions, thinned to a round step")
    func ticks() {
        #expect(SequencePlot(table(5)).xAxisValues() == [1, 2, 3, 4, 5])
        #expect(SequencePlot(table(12)).xAxisValues() == [1, 3, 5, 7, 9, 11])
        #expect(SequencePlot(table(40)).xAxisValues() == [1, 11, 21, 31])
    }

    @Test("bands and markers sit between whole positions")
    func helpers() {
        #expect(SequenceBand.covering(2, through: 3) == SequenceBand(start: 1.5, end: 3.5))
        #expect(SequenceMarker.after(3, label: "Changed").position == 3.5)
    }
}
