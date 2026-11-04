//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Raster+ExampleData.swift
//  Graph
//
//  `Data/baja_elevation.tif` is WorldClim 30-arc-second elevation (about
//  1 km cells) cropped to `Graph.lophoGraph.studyArea()`, stored as Int16
//  (WorldClim elevations are whole metres). The DEM ends at 30° N, so the
//  northernmost lopho sites fall just off it. It lives here, beside the lopho
//  graph, rather than in Matrix, so views can pair the two. The full tile it
//  was cut from is Tests/MatrixTests/Fixtures/geotiff/alt_baja.tif.
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix

public extension Raster {

    /// WorldClim elevation in metres over the lopho study area in Baja California and Sonora.
    ///
    /// A 871 × 684 grid of 30-arc-second cells from 115.21° W to 109.51° W and 22.74° N to 30° N, with the ocean
    /// missing. Pair it with ``Graph/lophoGraph`` for examples and previews:
    ///
    /// ```swift
    /// RasterMapView(raster: .bajaElevation, graph: .lophoGraph)
    /// ```
    ///
    /// Loaded from the bundled `Data/baja_elevation.tif`, so a failure here is a packaging bug and traps.
    static var bajaElevation: Raster {
        let url = try! GraphExampleData.url("baja_elevation", extension: "tif")
        return try! importGeoTIFF(contentsOf: url, name: "Elevation (m)")
    }
}
