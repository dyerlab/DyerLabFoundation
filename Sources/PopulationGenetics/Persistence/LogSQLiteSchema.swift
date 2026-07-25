//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  LogSQLiteSchema.swift
//  PopulationGenetics
//
//  The on-disk schema for the `.log` component — a generic, append-only
//  running log of timestamped notes (file I/O, warnings, errors, documented
//  assumptions, ...). Fully domain-neutral; movable as-is to a future
//  generic `Persistence` target.
//

import Foundation

enum LogSchemaComponent {

    /// Bumped whenever the on-disk layout changes in a way that breaks
    /// existing readers.
    static let currentSchemaVersion: Int32 = 1

    static let metaVersionKey = "log_schema_version"
    static let hasFlagKey = "has_log"

    static let createStatements: [String] = [
        """
        CREATE TABLE log_entries (
            ordinal      INTEGER PRIMARY KEY,
            uuid         TEXT NOT NULL UNIQUE,
            timestamp    TEXT NOT NULL,
            log_type     TEXT NOT NULL,
            analysis_tag TEXT,
            message      TEXT NOT NULL
        )
        """,
    ]

    /// Creates this component's tables and records its version + `has_log`
    /// flag (initially `false`) in `meta`.
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
    static func isPresent(in connection: SQLiteConnection) throws -> Bool {
        let stmt = try connection.prepare("SELECT 1 FROM meta WHERE key = ?")
        stmt.bind(metaVersionKey, at: 1)
        return try stmt.step()
    }

    /// Validates that this component's `meta` version row matches
    /// `currentSchemaVersion`. Assumes the caller already confirmed presence.
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
}
