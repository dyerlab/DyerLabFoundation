//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ProjectMetadataSchema.swift
//  PopulationGenetics
//
//  The `project_metadata` table: free-form string key/value pairs describing
//  the project. Holds the reserved project-identity keys (`project_name`,
//  `species`, `description`) alongside any keys an app adds. Kept apart from
//  `meta`, which is the store's own bookkeeping (schema versions, `has_*`
//  flags, counts), so an app key can never clobber a reserved one there.
//  Unlike the five `StoreComponents`, this table is part of every file.
//
//  Created by Rodney Dyer on 2026.10.24.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

enum ProjectMetadataSchema {

    static let createStatement = """
        CREATE TABLE project_metadata (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
        """

    /// Creates the table and stores the file's initial pairs.
    ///
    /// - Parameters:
    ///   - values: The pairs a new file starts with.
    ///   - connection: An open, writable connection.
    /// - Throws: ``PersistenceError/sqliteError(code:message:)`` if a statement fails.
    static func createSchema(in connection: SQLiteConnection, values: [String: String]) throws {
        try connection.execute(createStatement)
        try write(values, connection: connection)
    }

    /// Every row of `project_metadata`.
    ///
    /// - Parameter connection: The open connection to read.
    /// - Returns: The stored key/value pairs.
    /// - Throws: ``PersistenceError/sqliteError(code:message:)`` if the query fails.
    static func read(_ connection: SQLiteConnection) throws -> [String: String] {
        let stmt = try connection.prepare("SELECT key, value FROM project_metadata")
        var values: [String: String] = [:]
        while try stmt.step() {
            values[stmt.columnText(at: 0)] = stmt.columnText(at: 1)
        }
        return values
    }

    /// Inserts or replaces each pair. Doesn't open a transaction of its own.
    ///
    /// - Parameters:
    ///   - values: The pairs to store.
    ///   - connection: An open, writable connection.
    /// - Throws: ``PersistenceError/sqliteError(code:message:)`` if an insert fails.
    static func write(_ values: [String: String], connection: SQLiteConnection) throws {
        guard !values.isEmpty else { return }
        let stmt = try connection.prepare("INSERT OR REPLACE INTO project_metadata (key, value) VALUES (?, ?)")
        for (key, value) in values {
            stmt.reset()
            stmt.bind(key, at: 1)
            stmt.bind(value, at: 2)
            _ = try stmt.step()
        }
    }

    /// Deletes each key. Doesn't open a transaction of its own.
    ///
    /// - Parameters:
    ///   - keys: The keys to remove; missing keys are ignored.
    ///   - connection: An open, writable connection.
    /// - Throws: ``PersistenceError/sqliteError(code:message:)`` if a delete fails.
    static func remove(_ keys: [String], connection: SQLiteConnection) throws {
        guard !keys.isEmpty else { return }
        let stmt = try connection.prepare("DELETE FROM project_metadata WHERE key = ?")
        for key in keys {
            stmt.reset()
            stmt.bind(key, at: 1)
            _ = try stmt.step()
        }
    }
}
