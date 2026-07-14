//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2025 The Dyer Laboratory.  All Rights Reserved.
//
//  PlacardMapView.swift
//  GeneticStudio
//
//  Created by Rodney Dyer on 4/30/24.
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
        VStack{
            Map {
                ForEach( placards ) { item in
                    
                    Annotation( item.title,
                                coordinate: item.coordinate,
                                anchor: .center,
                                content: {
                        ZStack {
                            Circle()
                                .fill( .secondary )
                            Image(systemName: item.icon)
                                .foregroundColor( .red )
                                .bold()
                        }
                    }
                    )
                    
                }
            }
            .mapControlVisibility( .automatic )
            .mapStyle( .hybrid )
        }
       

    }
}

#Preview {
    PlacardMapView( placards: MapPlacard.randomSites )
}


