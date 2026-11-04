//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ProjectStore+Rasters.swift
//  PopulationGenetics
//
//  Read/write access to the `.rasters` component. Unlike `matrices`, layers
//  are keyed by name and replaced in place: a raster can run to tens of
//  megabytes, so re-importing a layer mustn't leave old copies behind.
//  `Raster` is a `Sendable` value, so it crosses the actor boundary directly.
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix

extension ProjectStore {

    /// Stores a raster layer under its name, replacing any layer already stored with that name.
    ///
    /// A replaced layer keeps its position in ``rasters()`` and its identifier.
    ///
    /// - Parameters:
    ///   - raster: The layer to store.
    ///   - description: Optional longer description.
    /// - Throws: ``PersistenceError/readOnly`` for a read-only store, ``PersistenceError/componentNotPresent(_:)``
    ///   without a `.rasters` component, ``PersistenceError/notOpen``, or
    ///   ``PersistenceError/sqliteError(code:message:)``.
    public func writeRaster(_ raster: Raster, description: String? = nil) async throws {
        guard mode == .readWrite else { throw PersistenceError.readOnly }
        try requireComponent(.rasters, "rasters")
        let connection = try requireConnection()
        try connection.beginTransaction()
        do {
            let ordinalStatement = try connection.prepare("SELECT COALESCE(MAX(ordinal), -1) + 1 FROM rasters")
            _ = try ordinalStatement.step()
            let ordinal = ordinalStatement.columnInt(at: 0)
            let stmt = try connection.prepare("""
                INSERT INTO rasters (ordinal, uuid, name, description, created_at, rows, cols,
                                     west, east, south, north, crs, data)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(name) DO UPDATE SET
                    description = excluded.description, created_at = excluded.created_at,
                    rows = excluded.rows, cols = excluded.cols,
                    west = excluded.west, east = excluded.east, south = excluded.south, north = excluded.north,
                    crs = excluded.crs, data = excluded.data
                """)
            stmt.bind(ordinal, at: 1)
            stmt.bind(UUID().uuidString, at: 2)
            stmt.bind(raster.name, at: 3)
            stmt.bindOptional(description, at: 4)
            stmt.bind(ISO8601DateFormatter().string(from: Date()), at: 5)
            stmt.bind(raster.rows, at: 6)
            stmt.bind(raster.cols, at: 7)
            stmt.bind(raster.extent.west, at: 8)
            stmt.bind(raster.extent.east, at: 9)
            stmt.bind(raster.extent.south, at: 10)
            stmt.bind(raster.extent.north, at: 11)
            stmt.bind(raster.crs.definition, at: 12)
            stmt.bind(RastersSchemaComponent.encode(raster.values), at: 13)
            _ = try stmt.step()
            try setMetaFlag(RastersSchemaComponent.hasFlagKey, to: true, connection: connection)
            try connection.commit()
        } catch {
            try? connection.rollback()
            throw error
        }
    }

    /// Metadata for every stored raster layer, in the order they were first written.
    ///
    /// - Returns: The layers' metadata.
    /// - Throws: ``PersistenceError/componentNotPresent(_:)`` without a `.rasters` component,
    ///   ``PersistenceError/notOpen``, ``PersistenceError/corruptData(_:)`` for an unreadable row, or
    ///   ``PersistenceError/sqliteError(code:message:)``.
    public func rasters() async throws -> [StoredRasterInfo] {
        try requireComponent(.rasters, "rasters")
        let connection = try requireConnection()
        let stmt = try connection.prepare("""
            SELECT uuid, name, description, created_at, rows, cols, west, east, south, north, crs
            FROM rasters ORDER BY ordinal
            """)
        let formatter = ISO8601DateFormatter()
        var out: [StoredRasterInfo] = []
        while try stmt.step() {
            out.append(try makeRasterInfo(stmt: stmt, formatter: formatter))
        }
        return out
    }

    /// The raster layer stored under `name`.
    ///
    /// - Parameter name: The layer's name.
    /// - Returns: The layer, or `nil` if none is stored under that name.
    /// - Throws: ``PersistenceError/componentNotPresent(_:)`` without a `.rasters` component,
    ///   ``PersistenceError/notOpen``, ``PersistenceError/corruptData(_:)`` if the stored row isn't a valid raster,
    ///   or ``PersistenceError/sqliteError(code:message:)``.
    public func raster(named name: String) async throws -> Raster? {
        try requireComponent(.rasters, "rasters")
        let connection = try requireConnection()
        let stmt = try connection.prepare("""
            SELECT rows, cols, west, east, south, north, crs, data FROM rasters WHERE name = ?
            """)
        stmt.bind(name, at: 1)
        guard try stmt.step() else { return nil }
        let rows = stmt.columnInt(at: 0)
        let cols = stmt.columnInt(at: 1)
        guard let extent = RasterExtent(west: stmt.columnDouble(at: 2), east: stmt.columnDouble(at: 3),
                                        south: stmt.columnDouble(at: 4), north: stmt.columnDouble(at: 5)),
              let crs = CoordinateReferenceSystem(definition: stmt.columnText(at: 6)),
              let values = RastersSchemaComponent.decode(stmt.columnBlob(at: 7), count: rows * cols),
              let raster = Raster(name: name, rows: rows, cols: cols, extent: extent, crs: crs, values: values) else {
            throw PersistenceError.corruptData("raster '\(name)' has an invalid extent, size or coordinate system")
        }
        return raster
    }

    /// Deletes the raster layer stored under `name`, if there is one.
    ///
    /// - Parameter name: The layer's name.
    /// - Returns: `true` if a layer was deleted.
    /// - Throws: ``PersistenceError/readOnly`` for a read-only store, ``PersistenceError/componentNotPresent(_:)``
    ///   without a `.rasters` component, ``PersistenceError/notOpen``, or
    ///   ``PersistenceError/sqliteError(code:message:)``.
    @discardableResult
    public func removeRaster(named name: String) async throws -> Bool {
        guard mode == .readWrite else { throw PersistenceError.readOnly }
        try requireComponent(.rasters, "rasters")
        let connection = try requireConnection()
        let existing = try connection.prepare("SELECT 1 FROM rasters WHERE name = ?")
        existing.bind(name, at: 1)
        guard try existing.step() else { return false }
        let stmt = try connection.prepare("DELETE FROM rasters WHERE name = ?")
        stmt.bind(name, at: 1)
        _ = try stmt.step()
        let remaining = try connection.prepare("SELECT COUNT(*) FROM rasters")
        _ = try remaining.step()
        try setMetaFlag(RastersSchemaComponent.hasFlagKey, to: remaining.columnInt(at: 0) > 0, connection: connection)
        return true
    }

    private func makeRasterInfo(stmt: Statement, formatter: ISO8601DateFormatter) throws -> StoredRasterInfo {
        let uuidString = stmt.columnText(at: 0)
        guard let uuid = UUID(uuidString: uuidString) else {
            throw PersistenceError.corruptData("invalid raster uuid: \(uuidString)")
        }
        let createdAtString = stmt.columnText(at: 3)
        guard let createdAt = formatter.date(from: createdAtString) else {
            throw PersistenceError.corruptData("invalid raster created_at: \(createdAtString)")
        }
        guard let extent = RasterExtent(west: stmt.columnDouble(at: 6), east: stmt.columnDouble(at: 7),
                                        south: stmt.columnDouble(at: 8), north: stmt.columnDouble(at: 9)),
              let crs = CoordinateReferenceSystem(definition: stmt.columnText(at: 10)) else {
            throw PersistenceError.corruptData("invalid raster extent or crs for \(stmt.columnText(at: 1))")
        }
        return StoredRasterInfo(id: uuid, name: stmt.columnText(at: 1),
                                description: stmt.columnIsNull(at: 2) ? nil : stmt.columnText(at: 2),
                                createdAt: createdAt, rows: stmt.columnInt(at: 4), cols: stmt.columnInt(at: 5),
                                extent: extent, crs: crs)
    }
}
