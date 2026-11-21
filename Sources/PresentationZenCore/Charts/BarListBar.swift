//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  BarListBar.swift
//  PresentationZenCore
//
//  Created by Rodney Dyer on 2026.11.20.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// One bar of a ``BarListPlot``, with its value after it.
struct BarListBar: View {
    /// The text shown after the bar.
    let value: String
    /// The bar's length as a fraction of the longest bar, 0 to 1.
    let fraction: Double
    /// The bar color; `nil` uses the environment's tint.
    let color: Color?

    /// Room kept after the bar for the value.
    private let labelWidth: CGFloat = 36

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, minHeight: 18)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color.map(AnyShapeStyle.init) ?? AnyShapeStyle(.tint))
                            .frame(width: max(2, (proxy.size.width - labelWidth) * fraction))
                        Text(value)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                    .frame(maxHeight: .infinity)
                }
            }
    }
}

// MARK: - Previews

#Preview {
    VStack(spacing: 8) {
        BarListBar(value: "38", fraction: 1, color: nil)
        BarListBar(value: "12", fraction: 12 / 38, color: .orange)
        BarListBar(value: "1", fraction: 1 / 38, color: nil)
    }
    .padding()
}
