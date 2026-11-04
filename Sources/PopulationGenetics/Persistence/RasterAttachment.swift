//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RasterAttachment.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix

/// One raster layer with its description, the unit `saveSnapshot`/`loadSnapshot` pass for the `.rasters` component.
public struct RasterAttachment: Sendable, Equatable {
    /// The layer, whose `name` is its key in the project.
    public let raster: Raster
    /// Optional longer description.
    public let description: String?

    /// Initializes a raster attachment.
    ///
    /// - Parameters:
    ///   - raster: The layer.
    ///   - description: Optional longer description.
    public init(raster: Raster, description: String? = nil) {
        self.raster = raster
        self.description = description
    }
}
