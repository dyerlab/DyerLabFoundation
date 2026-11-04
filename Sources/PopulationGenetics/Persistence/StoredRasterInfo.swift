//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StoredRasterInfo.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix

/// Metadata for a raster layer stored in a project, without its cells.
///
/// Fetch the cells with `ProjectStore.raster(named:)`.
public struct StoredRasterInfo: Sendable, Identifiable, Equatable {
    /// Unique identifier for this layer.
    public let id: UUID
    /// The layer's name, unique within the project.
    public let name: String
    /// Optional longer description.
    public let description: String?
    /// When this layer was last written.
    public let createdAt: Date
    /// The number of rows.
    public let rows: Int
    /// The number of columns.
    public let cols: Int
    /// The outer edges of the grid, in ``crs`` coordinates.
    public let extent: RasterExtent
    /// The coordinate system the grid is laid out in.
    public let crs: CoordinateReferenceSystem

    /// Initializes raster metadata.
    ///
    /// - Parameters:
    ///   - id: Unique identifier.
    ///   - name: The layer's name.
    ///   - description: Optional longer description.
    ///   - createdAt: When the layer was last written.
    ///   - rows: The number of rows.
    ///   - cols: The number of columns.
    ///   - extent: The outer edges of the grid, in `crs` coordinates.
    ///   - crs: The coordinate system.
    public init(id: UUID,
                name: String,
                description: String?,
                createdAt: Date,
                rows: Int,
                cols: Int,
                extent: RasterExtent,
                crs: CoordinateReferenceSystem) {
        self.id = id
        self.name = name
        self.description = description
        self.createdAt = createdAt
        self.rows = rows
        self.cols = cols
        self.extent = extent
        self.crs = crs
    }
}
