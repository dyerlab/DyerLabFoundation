//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IndividualPlacard.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2025.05.30.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// A compact view displaying individual information including name and coordinates.
///
/// Shows the individual's name prominently with latitude and longitude as secondary
/// text when spatial data is available.
struct IndividualPlacard: View {
    /// The individual to display.
    var individual: Individual
    var body: some View {
        HStack {
            Text(individual.name)
                .font(.title)

            if let lat = individual.latitude,
                let lon = individual.longitude {
                VStack(alignment: .leading) {
                    Text("\(lat)")
                    Text("\(lon)")
                }
                .foregroundStyle(.secondary)
                .font(.footnote)
            }
        }
    }
}

#if DEBUG

// MARK: - Previews

#Preview {
    IndividualPlacard(individual: Individual(name: "Bob",
                                              latitude: 23.534,
                                              longitude: -77.234))
    .padding()
}
#endif
