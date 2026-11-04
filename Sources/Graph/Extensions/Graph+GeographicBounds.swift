//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Graph+GeographicBounds.swift
//  Graph
//
//  The bridge from a spatial graph to Matrix's `GeographicBounds`, so a
//  raster can be cropped to the graph's study area on import.
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix

public extension Graph {

    /// The smallest bounds enclosing every node that has a coordinate, or `nil` if none do.
    var geographicBounds: GeographicBounds? {
        let coordinates = nodes.compactMap(\.coordinate)
        return GeographicBounds(longitudes: coordinates.map(\.longitude), latitudes: coordinates.map(\.latitude))
    }

    /// The graph's study area: its nodes' bounds widened by a buffer, for cropping a raster on import.
    ///
    /// ```swift
    /// let elevation = try importGeoTIFF(contentsOf: url, cropTo: graph.studyArea())
    /// ```
    ///
    /// - Parameters:
    ///   - fraction: The buffer on each side as a fraction of the bounds' width or height (default `0.1`).
    ///   - minimum: The smallest buffer on any side, in degrees (default `0.01`, about 1 km).
    /// - Returns: The buffered bounds, or `nil` if no node has a coordinate.
    func studyArea(buffer fraction: Double = 0.1, minimum: Double = 0.01) -> GeographicBounds? {
        geographicBounds?.buffered(by: fraction, minimum: minimum)
    }
}
