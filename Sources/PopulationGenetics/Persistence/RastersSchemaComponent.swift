//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RastersSchemaComponent.swift
//  PopulationGenetics
//
//  The on-disk schema for the `.rasters` component: named single-band
//  `Raster` layers (elevation, one NLCD class, ...). The layout is kept
//  plain so gstudio can read it from R without this package. Each row's
//  `data` is `rows * cols` IEEE 754 single-precision floats, little-endian,
//  row-major with the northernmost row first, NaN for a missing cell; the
//  extent columns are the outer cell edges in the layer's own coordinates
//  (degrees, or metres for UTM/Albers), and `crs` is "EPSG:n" or, for a
//  projection without a code, a PROJ string. In R:
//
//      v <- readBin(row$data[[1]], "numeric", n = row$rows * row$cols, size = 4, endian = "little")
//      r <- terra::rast(matrix(v, nrow = row$rows, byrow = TRUE),
//                       extent = terra::ext(row$west, row$east, row$south, row$north),
//                       crs = row$crs)
//
//  Change this layout only together with gstudio's reader, and bump the
//  schema version when you do.
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

enum RastersSchemaComponent {

    /// Bumped whenever the on-disk layout changes in a way that breaks existing readers.
    static let currentSchemaVersion: Int32 = 1

    static let metaVersionKey = "rasters_schema_version"
    static let hasFlagKey = "has_rasters"

    static let createStatements: [String] = [
        """
        CREATE TABLE rasters (
            ordinal     INTEGER PRIMARY KEY,
            uuid        TEXT NOT NULL UNIQUE,
            name        TEXT NOT NULL UNIQUE,
            description TEXT,
            created_at  TEXT NOT NULL,
            rows        INTEGER NOT NULL,
            cols        INTEGER NOT NULL,
            west        REAL NOT NULL,
            east        REAL NOT NULL,
            south       REAL NOT NULL,
            north       REAL NOT NULL,
            crs         TEXT NOT NULL,
            data        BLOB NOT NULL
        )
        """,
    ]

    /// Creates this component's table and records its version and `has_rasters` flag (initially `false`) in `meta`.
    ///
    /// - Parameter connection: The open connection to install into.
    /// - Throws: ``PersistenceError/sqliteError(code:message:)`` if a statement fails.
    static func createSchema(in connection: SQLiteConnection) throws {
        for statement in createStatements {
            try connection.execute(statement)
        }
        let stmt = try connection.prepare("INSERT INTO meta (key, value) VALUES (?, ?)")
        stmt.bind(metaVersionKey, at: 1)
        stmt.bind(String(currentSchemaVersion), at: 2)
        _ = try stmt.step()
        stmt.reset()
        stmt.bind(hasFlagKey, at: 1)
        stmt.bind("false", at: 2)
        _ = try stmt.step()
    }

    /// `true` if this component's table was created for the currently open file.
    ///
    /// - Parameter connection: The open connection to inspect.
    /// - Returns: `true` if `meta` has this component's version row.
    /// - Throws: ``PersistenceError/sqliteError(code:message:)`` if the query fails.
    static func isPresent(in connection: SQLiteConnection) throws -> Bool {
        let stmt = try connection.prepare("SELECT 1 FROM meta WHERE key = ?")
        stmt.bind(metaVersionKey, at: 1)
        return try stmt.step()
    }

    /// Validates that this component's `meta` version row matches `currentSchemaVersion`. Assumes the caller
    /// already confirmed presence.
    ///
    /// - Parameter connection: The open connection to inspect.
    /// - Throws: ``PersistenceError/schemaVersionMismatch(found:expected:)`` for a different version,
    ///   ``PersistenceError/corruptData(_:)`` if the version row is missing or unreadable, or
    ///   ``PersistenceError/sqliteError(code:message:)`` if the query fails.
    static func validateSchemaVersion(of connection: SQLiteConnection) throws {
        let stmt = try connection.prepare("SELECT value FROM meta WHERE key = ?")
        stmt.bind(metaVersionKey, at: 1)
        guard try stmt.step() else {
            throw PersistenceError.corruptData("missing \(metaVersionKey) row in meta table")
        }
        let valueString = stmt.columnText(at: 0)
        guard let found = Int32(valueString) else {
            throw PersistenceError.corruptData("invalid \(metaVersionKey) value: \(valueString)")
        }
        guard found == currentSchemaVersion else {
            throw PersistenceError.schemaVersionMismatch(found: found, expected: currentSchemaVersion)
        }
    }

    /// A raster's cells as little-endian `Float32` bytes.
    static func encode(_ values: [Float]) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: values.count * 4)
        for (index, value) in values.enumerated() {
            let bits = value.bitPattern
            for byte in 0 ..< 4 {
                bytes[index * 4 + byte] = UInt8(truncatingIfNeeded: bits >> UInt32(8 * byte))
            }
        }
        return bytes
    }

    /// Cells decoded from little-endian `Float32` bytes, or `nil` if the byte count isn't `count * 4`.
    static func decode(_ bytes: [UInt8], count: Int) -> [Float]? {
        guard bytes.count == count * 4 else { return nil }
        return (0 ..< count).map { index in
            let offset = index * 4
            let bits = UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8
                | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
            return Float(bitPattern: bits)
        }
    }
}
