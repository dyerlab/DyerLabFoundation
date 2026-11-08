//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MatricesSchemaComponent.swift
//  PopulationGenetics
//
//  The on-disk schema for the `.matrices` component — named, generic
//  `Matrix` attachments (a derived Fst distance matrix, PCA loadings, ...),
//  distinct from `.geneticData`'s specialized individual x locus genotype
//  encoding. `data` holds `Matrix`'s existing `Codable` encoding
//  (`Matrix+Codable.swift`), produced/consumed by the caller outside actor
//  isolation — see `ProjectStore+Matrices.swift`. Fully domain-neutral;
//  movable as-is to a future generic `Persistence` target.
//
//  Created by Rodney Dyer on 2026.07.25.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

enum MatricesSchemaComponent {

    /// Bumped whenever the on-disk layout changes in a way that breaks
    /// existing readers.
    ///
    /// Version 2 (2026-11-08) added the `spec` column: app-defined JSON saying what a matrix holds (for GeneticStudio,
    /// a `DistanceSpec`), as a figure's `spec` does. Version 1 files are read with no spec, and are migrated in place
    /// when opened read-write.
    static let currentSchemaVersion: Int32 = 2

    static let metaVersionKey = "matrices_schema_version"
    static let hasFlagKey = "has_matrices"

    static let createStatements: [String] = [
        """
        CREATE TABLE matrices (
            ordinal     INTEGER PRIMARY KEY,
            uuid        TEXT NOT NULL UNIQUE,
            name        TEXT NOT NULL,
            description TEXT,
            created_at  TEXT NOT NULL,
            data        BLOB NOT NULL,
            spec        TEXT
        )
        """,
    ]

    /// Creates this component's tables and records its version + `has_matrices`
    /// flag (initially `false`) in `meta`.
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

    /// `true` if this component's tables were created for the currently open file.
    ///
    /// - Parameter connection: The open connection to inspect.
    /// - Returns: `true` if `meta` has this component's version row.
    /// - Throws: ``PersistenceError/sqliteError(code:message:)`` if the query fails.
    static func isPresent(in connection: SQLiteConnection) throws -> Bool {
        let stmt = try connection.prepare("SELECT 1 FROM meta WHERE key = ?")
        stmt.bind(metaVersionKey, at: 1)
        return try stmt.step()
    }

    /// Validates that this component's `meta` version row is one this code reads: 1 or
    /// `currentSchemaVersion`. Assumes the caller already confirmed presence.
    ///
    /// - Parameter connection: The open connection to inspect.
    /// - Returns: The file's version.
    /// - Throws: ``PersistenceError/schemaVersionMismatch(found:expected:)`` for any other version,
    ///   ``PersistenceError/corruptData(_:)`` if the version row is missing or unreadable, or
    ///   ``PersistenceError/sqliteError(code:message:)`` if the query fails.
    @discardableResult
    static func validateSchemaVersion(of connection: SQLiteConnection) throws -> Int32 {
        let stmt = try connection.prepare("SELECT value FROM meta WHERE key = ?")
        stmt.bind(metaVersionKey, at: 1)
        guard try stmt.step() else {
            throw PersistenceError.corruptData("missing \(metaVersionKey) row in meta table")
        }
        let valueString = stmt.columnText(at: 0)
        guard let found = Int32(valueString) else {
            throw PersistenceError.corruptData("invalid \(metaVersionKey) value: \(valueString)")
        }
        guard (1...currentSchemaVersion).contains(found) else {
            throw PersistenceError.schemaVersionMismatch(found: found, expected: currentSchemaVersion)
        }
        return found
    }

    /// Brings a version 1 table up to the current version by adding the `spec` column.
    ///
    /// - Parameters:
    ///   - connection: The open, writable connection.
    ///   - version: The file's version, from ``validateSchemaVersion(of:)``.
    /// - Throws: ``PersistenceError/sqliteError(code:message:)`` if a statement fails.
    static func migrate(_ connection: SQLiteConnection, from version: Int32) throws {
        guard version < 2 else { return }
        try connection.execute("ALTER TABLE matrices ADD COLUMN spec TEXT")
        let stmt = try connection.prepare("UPDATE meta SET value = ? WHERE key = ?")
        stmt.bind(String(currentSchemaVersion), at: 1)
        stmt.bind(metaVersionKey, at: 2)
        _ = try stmt.step()
    }
}
