//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DailyPresencePlot.swift
//  PresentationZenCore
//
//  A month of days against a set of series, marking the days each one has data. It was ObjectiveKitUI's
//  DataDailyPlot, which read an Objective's assessments itself; it now takes DailyPresenceSeries values so FOTJ,
//  EcoConnect and MyDeck can all use it.
//
//  Created by Rodney Dyer on 2025.03.31.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import DyerlabCore
import SwiftUI

/// A month grid with a row per day and a column per series, filled where the series has data that day.
///
/// A ``MonthSelectorView`` on top steps the month.
public struct DailyPresencePlot: View {
    /// The columns, in order.
    let series: [DailyPresenceSeries]
    /// The fill for a day with data.
    let tint: Color

    /// A date in the month shown.
    @State private var month: Date

    /// The grid columns: one for the day number, then one per series.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: 1 + series.count)
    }

    /// Creates a daily grid.
    /// - Parameters:
    ///   - series: The columns, in order.
    ///   - month: A date in the month to show first. Defaults to now.
    ///   - tint: The fill for a day with data. Defaults to blue.
    public init(series: [DailyPresenceSeries], month: Date = .now, tint: Color = .blue) {
        self.series = series
        self.tint = tint
        self._month = State(initialValue: month)
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                MonthSelectorView(date: $month)

                LazyVGrid(columns: columns, spacing: 6) {
                    Text("Day")
                        .font(.headline)
                    ForEach(series) { item in
                        Image(systemName: item.systemImage)
                            .font(.headline)
                            .accessibilityLabel(item.name)
                    }

                    ForEach(Date.daysOfMonth(containing: month), id: \.self) { day in
                        Text(day, format: .dateTime.day())
                            .monospacedDigit()
                        ForEach(series) { item in
                            cell(item.hasData(on: day))
                                .accessibilityLabel(
                                    "\(item.name), \(day.formatted(date: .abbreviated, time: .omitted))")
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    /// A filled square for a day with data, an outline otherwise.
    private func cell(_ hasData: Bool) -> some View {
        Image(systemName: hasData ? "square.fill" : "square")
            .foregroundStyle(hasData ? tint : .secondary)
            .accessibilityValue(hasData ? "Has data" : "No data")
    }
}

// MARK: - Previews

#Preview {
    DailyPresencePlot(series: [
        DailyPresenceSeries(name: "Mood", systemImage: "face.smiling", dates: Date.randomDates(count: 12, days: 30)),
        DailyPresenceSeries(name: "Steps", systemImage: "figure.walk", dates: Date.randomDates(count: 20, days: 30)),
        DailyPresenceSeries(name: "Notes", systemImage: "text.alignleft", dates: Date.randomDates(count: 5, days: 30)),
    ])
}
