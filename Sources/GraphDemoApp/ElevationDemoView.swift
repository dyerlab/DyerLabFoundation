//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ElevationDemoView.swift
//  GraphDemoApp
//
//  The bundled Baja elevation raster under the lopho graph, with a slider
//  for the raster's opacity.
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Graph
import Matrix
import SwiftUI

/// The lopho graph over WorldClim elevation, with adjustable raster opacity.
struct ElevationDemoView: View {
    // Loaded once, so moving the slider only changes the overlay's opacity.
    @State private var raster = Raster.bajaElevation
    @State private var graph = Graph.lophoGraph
    @State private var opacity = 0.7

    var body: some View {
        RasterMapView(raster: raster, graph: graph, opacity: opacity)
            .overlay(alignment: .bottomLeading) {
                RasterOpacitySlider(opacity: $opacity)
                    .padding()
            }
    }
}

#Preview {
    ElevationDemoView()
}
