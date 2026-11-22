//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ActivityGrid.swift
//  PresentationZenCore
//
//  A contribution-style grid of recent days. Moved from ObjectiveKitUI so any app can draw one from a list of
//  dates; it knows nothing about where the dates came from.
//
//  Created by Rodney Dyer on 2024.11.20.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import DyerlabCore
import SwiftUI

/// A contribution-style grid of squares, one per day, filled on days with activity.
///
/// Days fill seven-row columns from oldest to newest, after a column of weekday labels. A caption above the grid
/// shows the total count.
public struct ActivityGrid: View {
    /// The number of dates that fell on one day.
    struct DayCount: Hashable {
        /// Midnight at the start of the day.
        var date: Date
        /// How many dates fell on that day.
        var count: Int
    }

    /// Size of each day's square, in points.
    static let boxSize: CGFloat = 15
    /// Spacing between squares, in points.
    static let spacing: CGFloat = 4

    /// One count per day, oldest first.
    let data: [DayCount]
    /// The word after the total in the caption, such as "entries".
    let noun: String
    /// The fill for a day with activity.
    let tint: Color

    /// Seven fixed-height grid rows, one per day of the week.
    private var rows: [GridItem] {
        Array(repeating: GridItem(.fixed(Self.boxSize), spacing: Self.spacing), count: 7)
    }

    /// Row labels for the first seven days.
    ///
    /// Days whose one-digit weekday number is 1 through 5 get an abbreviated weekday name, and the rest are left
    /// blank. With fewer than seven days of ``data``, only those days get labels.
    private var weekdays: [String] {
        data.prefix(7).map { day in
            let digit = day.date.formatted(Date.FormatStyle().weekday(.oneDigit))
            return ["1", "2", "3", "4", "5"].contains(digit)
                ? day.date.formatted(Date.FormatStyle().weekday(.abbreviated))
                : ""
        }
    }

    /// The total across every day shown.
    private var total: Int {
        data.reduce(0) { $0 + $1.count }
    }

    /// Creates a grid counting `dates` per day over the last `coverage` days, including today.
    /// - Parameters:
    ///   - dates: The activity dates to count, such as entry dates.
    ///   - coverage: How many days to show.
    ///   - noun: The word after the total in the caption. Defaults to "entries".
    ///   - tint: The fill for a day with activity. Defaults to a translucent green.
    public init(dates: [Date], coverage: Int, noun: String = "entries", tint: Color = .green.opacity(0.5)) {
        let calendar = Calendar.current
        let today = Date.now.startOfDay
        let counts = Dictionary(grouping: dates, by: { $0.startOfDay }).mapValues(\.count)
        self.data = (0 ..< max(coverage, 0)).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
                .map { DayCount(date: $0, count: counts[$0] ?? 0) }
        }
        self.noun = noun
        self.tint = tint
    }

    public var body: some View {
        VStack(alignment: .center) {
            Text("\(total) \(noun)")
                .foregroundStyle(.secondary)
                .font(.caption)

            LazyHGrid(rows: rows, spacing: Self.spacing) {
                ForEach(weekdays.indices, id: \.self) { index in
                    Text(weekdays[index])
                        .font(.footnote)
                        .accessibilityHidden(true)
                }

                ForEach(data, id: \.self) { day in
                    Image(systemName: "square.fill")
                        .foregroundStyle(day.count > 0 ? tint : .gray.opacity(0.25))
                        .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                        .accessibilityValue("\(day.count)")
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews

#Preview {
    ActivityGrid(dates: Date.randomDates(count: 20, days: 70), coverage: 70)
        .padding()
}
