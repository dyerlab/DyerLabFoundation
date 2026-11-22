//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DailyPresenceSeries.swift
//  PresentationZenCore
//
//  One column of a DailyPresencePlot: a named thing and the days it has data. Apps build these from their own
//  models (ObjectiveKitUI makes one per assessment), so the plot stays free of them.
//
//  Created by Rodney Dyer on 2026.11.22.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import DyerlabCore
import Foundation

/// The days one series has data, for a column of ``DailyPresencePlot``.
public struct DailyPresenceSeries: Identifiable, Hashable, Sendable {
    /// A stable identifier.
    public var id: String
    /// The series' name, read by VoiceOver for its column.
    public var name: String
    /// The SF Symbol heading the column.
    public var systemImage: String
    /// Midnight at the start of each day with data.
    public var days: Set<Date>

    /// Creates a series.
    /// - Parameters:
    ///   - id: A stable identifier. Defaults to `name`.
    ///   - name: The series' name.
    ///   - systemImage: The SF Symbol heading the column.
    ///   - dates: When the series has data; any time of day counts for that day.
    public init(id: String? = nil, name: String, systemImage: String, dates: some Sequence<Date>) {
        self.id = id ?? name
        self.name = name
        self.systemImage = systemImage
        self.days = Set(dates.map(\.startOfDay))
    }

    /// Whether the series has data on the day containing `date`.
    /// - Parameter date: Any time on the day to check.
    public func hasData(on date: Date) -> Bool {
        days.contains(date.startOfDay)
    }
}
