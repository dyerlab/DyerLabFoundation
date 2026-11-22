//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MonthSelectorView.swift
//  PresentationZenCore
//
//  The month title with previous and next buttons. Moved from ObjectiveKitUI, where it was a prototype that also
//  listed the month's days with placeholders; now it only steps a bound date, and month views put it on top.
//
//  Created by Rodney Dyer on 2025.04.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// A month title between buttons that step a bound date back or forward one month.
public struct MonthSelectorView: View {
    /// A date in the month shown. The buttons move it by one month.
    @Binding var date: Date

    /// Creates a month navigator.
    /// - Parameter date: A date in the month shown.
    public init(date: Binding<Date>) {
        self._date = date
    }

    public var body: some View {
        HStack {
            Button("Previous Month", systemImage: "chevron.left") { step(-1) }
            Spacer()
            Text(date, format: .dateTime.month(.wide).year())
                .font(.title2.bold())
                .contentTransition(.numericText())
            Spacer()
            Button("Next Month", systemImage: "chevron.right") { step(1) }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
    }

    /// Moves ``date`` by `months`.
    private func step(_ months: Int) {
        guard let moved = Calendar.current.date(byAdding: .month, value: months, to: date) else { return }
        withAnimation { date = moved }
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var date = Date.now
    MonthSelectorView(date: $date)
        .padding()
}
