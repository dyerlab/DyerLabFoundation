//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PlacardMapView.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2024.04.30.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import MapKit
import SwiftUI

/// A map view that renders a collection of `MapPlacard` locations as circular icon annotations.
public struct PlacardMapView: View {
    /// The placards to display on the map.
    public var placards: [MapPlacard]

    /// Creates a map view for the given placards.
    ///
    /// - Parameter placards: The placards to display on the map.
    public init(placards: [MapPlacard]) {
        self.placards = placards
    }

    /// The map, with a circular icon annotation for each placard.
    public var body: some View {
        VStack {
            Map {
                ForEach(placards) { item in

                    Annotation(item.title,
                                coordinate: item.coordinate,
                                anchor: .center,
                                content: {
                        ZStack {
                            Circle()
                                .fill(.secondary)
                            Image(systemName: item.icon)
                                .foregroundStyle(.red)
                                .bold()
                        }
                    }
                    )

                }
            }
            .mapControlVisibility(.automatic)
            .mapStyle(.hybrid)
        }

    }
}

// MARK: - Previews

#Preview {
    PlacardMapView(placards: MapPlacard.randomSites)
}
