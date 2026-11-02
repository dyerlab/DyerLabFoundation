//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Date.swift
//  DyerlabCore
//
//  Created by Rodney Dyer on 2024.10.10.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

public extension Date {

    /// Extracts multiple calendar components at once.
    ///
    /// - Parameters:
    ///   - components: The components to extract (e.g. `.year, .month, .day`).
    ///   - calendar: The calendar to compute components in (defaults to the current one).
    /// - Returns: A `DateComponents` populated with just the requested fields.
    func get(_ components: Calendar.Component..., calendar: Calendar = Calendar.current) -> DateComponents {
        calendar.dateComponents(Set(components), from: self)
    }

    /// Extracts a single calendar component.
    ///
    /// - Parameters:
    ///   - component: The component to extract (e.g. `.year`).
    ///   - calendar: The calendar to compute the component in (defaults to the current one).
    /// - Returns: The integer value of `component` for this date.
    func get(_ component: Calendar.Component, calendar: Calendar = Calendar.current) -> Int {
        calendar.component(component, from: self)
    }

    /// Parses a date from an `MM/dd/yyyy` string.
    ///
    /// - Parameter text: The date string to parse.
    /// - Returns: The parsed date, or `nil` if `text` doesn't match `MM/dd/yyyy`.
    static func mdy(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.date(from: text)
    }

    // MARK: - Day Boundaries

    /// Midnight at the start of this date's day, in the current calendar.
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// One second before midnight at the end of this date's day (23:59:59), in the current calendar.
    var endOfDay: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay)!
    }

    /// Checks whether this date falls on the same calendar day as `day`.
    /// - Parameter day: Any time on the day to compare with.
    /// - Returns: `true` if this date is between the start and end of that day, inclusive.
    func onThisDay(day: Date) -> Bool {
        self >= day.startOfDay && self <= day.endOfDay
    }

    // MARK: - Month Boundaries

    /// The number of days in a month.
    /// - Parameters:
    ///   - monthNumber: The month (1 through 12). Defaults to this date's month.
    ///   - year: The year. Defaults to this date's year.
    /// - Returns: The number of days in that month, or `-1` if it can't be calculated.
    func daysInMonth(_ monthNumber: Int? = nil, _ year: Int? = nil) -> Int {
        let calendar = Calendar.current
        let components = DateComponents(year: year ?? calendar.component(.year, from: self),
                                        month: monthNumber ?? calendar.component(.month, from: self))
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date) else { return -1 }
        return range.count
    }

    /// Midnight on the first day of the month containing `currentDate`.
    /// - Parameter currentDate: Any date in the month.
    static func startOfMonth(currentDate: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: currentDate)
        return Calendar.current.date(from: components)!
    }

    /// Midnight at the start of the last day of the month containing `currentDate`.
    /// - Parameter currentDate: Any date in the month.
    static func endOfMonth(currentDate: Date) -> Date {
        Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth(currentDate: currentDate))!
    }

    // MARK: - Sample Data

    /// Generates random dates within the past `days` days, for previews and sample data.
    /// - Parameters:
    ///   - count: How many dates to generate.
    ///   - days: How many days back from now the dates can go.
    /// - Returns: `count` random dates, sorted oldest first.
    static func randomDates(count: Int, days: Int) -> [Date] {
        let dayRange = (-1.0 * Double(days))...0.0
        return (0 ..< count)
            .map { _ in Date(timeIntervalSinceNow: Double.random(in: dayRange) * 60 * 60 * 24) }
            .sorted()
    }

}
