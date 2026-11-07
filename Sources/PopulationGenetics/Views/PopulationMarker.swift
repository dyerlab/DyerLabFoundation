//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopulationMarker.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// A population's map marker: a disc showing how many individuals it holds.
public struct PopulationMarker: View {
    /// The number of individuals in the population.
    public let count: Int
    /// Called when the marker is clicked.
    public let action: () -> Void

    /// Creates a marker.
    ///
    /// - Parameters:
    ///   - count: The number of individuals in the population.
    ///   - action: Called when the marker is clicked.
    public init(count: Int, action: @escaping () -> Void) {
        self.count = count
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(count, format: .number)
                .font(.caption2.bold().monospacedDigit())
                .foregroundStyle(.white)
                .frame(minWidth: 26, minHeight: 26)
                .background(Circle().fill(.tint))
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .help("Zoom to population")
    }
}

// MARK: - Previews

#Preview {
    PopulationMarker(count: 100) {}
        .padding()
}
