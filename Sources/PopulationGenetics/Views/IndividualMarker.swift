//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IndividualMarker.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// One individual's map marker.
public struct IndividualMarker: View {
    /// Creates a marker.
    public init() {}

    public var body: some View {
        Circle()
            .fill(.tint)
            .stroke(.white, lineWidth: 1)
            .frame(width: PopulationClusters.markerSize - 2, height: PopulationClusters.markerSize - 2)
    }
}

// MARK: - Previews

#Preview {
    IndividualMarker()
        .padding()
}
