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
//  PresentationZen
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

}
