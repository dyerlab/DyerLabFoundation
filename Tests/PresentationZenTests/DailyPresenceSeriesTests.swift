//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DailyPresenceSeriesTests.swift
//  PresentationZenTests
//
//  Created by Rodney Dyer on 2026.11.22.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import DyerlabCore
import Foundation
import Testing
@testable import PresentationZenCore

struct DailyPresenceSeriesTests {

    let morning = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 4, hour: 8))!

    @Test("any time of day marks the whole day, and only that day")
    func days() {
        let series = DailyPresenceSeries(name: "Mood", systemImage: "face.smiling",
                                         dates: [morning, morning.addingTimeInterval(3_600)])
        #expect(series.days.count == 1)
        #expect(series.hasData(on: morning.endOfDay))
        #expect(!series.hasData(on: morning.endOfDay.addingTimeInterval(1)))
        #expect(series.id == "Mood")
    }
}
