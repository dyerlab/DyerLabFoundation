//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  FiguresSchemaComponent.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import PresentationZen

/// The on-disk schema for the `.figures` component.
///
/// R reads and writes these tables directly, so the layout is a public format: see the figure storage article in
/// the catalog, and bump the version with any change that would break an existing reader or writer.
enum FiguresSchemaComponent {

    /// Bumped whenever the on-disk layout changes in a way that breaks existing readers.
    static let currentSchemaVersion: Int32 = 1

    /// The `meta` key holding the schema version.
    static let metaVersionKey = "figures_schema_version"
    /// The `meta` key saying whether any figure has been written.
    static let hasFlagKey = "has_figures"

    /// The statements that create the component's tables.
    static let createStatements: [String] = [
        """
        CREATE TABLE figures (
            ordinal    INTEGER PRIMARY KEY,
            uuid       TEXT NOT NULL UNIQUE,
            title      TEXT NOT NULL,
            legend     TEXT NOT NULL DEFAULT '',
            source     TEXT NOT NULL DEFAULT '',
            form       TEXT,
            bins       INTEGER,
            x_label    TEXT,
            y_label    TEXT,
            generator  TEXT,
            spec       TEXT,
            r_code     TEXT,
            created_at TEXT NOT NULL
        )
        """,
        """
        CREATE TABLE figure_columns (
            figure_uuid TEXT NOT NULL REFERENCES figures(uuid),
            position    INTEGER NOT NULL,
            name        TEXT NOT NULL,
            kind        TEXT NOT NULL CHECK (kind IN ('number', 'text', 'date')),
            role        TEXT CHECK (role IN ('x', 'y', 'series', 'label')),
            data        TEXT NOT NULL,
            PRIMARY KEY (figure_uuid, position),
            UNIQUE (figure_uuid, name),
            UNIQUE (figure_uuid, role)
        )
        """,
        """
        CREATE TABLE figure_images (
            figure_uuid TEXT NOT NULL REFERENCES figures(uuid),
            name        TEXT NOT NULL,
            mime_type   TEXT NOT NULL,
            width       INTEGER,
            height      INTEGER,
            data        BLOB NOT NULL,
            PRIMARY KEY (figure_uuid, name)
        )
        """,
        recordsStatement,
    ]

    /// Creates the `figure_records` table, which files written before it existed lack; it is optional and additive,
    /// so it doesn't change the schema version.
    static let recordsStatement = """
        CREATE TABLE IF NOT EXISTS figure_records (
            figure_uuid      TEXT PRIMARY KEY REFERENCES figures(uuid),
            methods          TEXT NOT NULL DEFAULT '',
            results          TEXT NOT NULL DEFAULT '',
            notes            TEXT NOT NULL DEFAULT '[]',
            analyst_notes    TEXT NOT NULL DEFAULT '',
            data_version     TEXT,
            data_modified_at TEXT,
            app_version      TEXT
        )
        """

    /// Whether the open file has a `figure_records` table.
    ///
    /// - Parameter connection: The open connection to inspect.
    /// - Returns: `true` if the table exists.
    /// - Throws: ``PersistenceError/sqliteError(code:message:)`` if the query fails.
    static func hasRecords(in connection: SQLiteConnection) throws -> Bool {
        let stmt = try connection.prepare("""
            SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'figure_records'
            """)
        return try stmt.step()
    }

    /// Creates this component's tables and records its version and `has_figures` flag in `meta`.
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

    /// Whether this component's tables exist in the open file.
    ///
    /// - Parameter connection: The open connection to inspect.
    /// - Returns: `true` if `meta` has this component's version row.
    /// - Throws: ``PersistenceError/sqliteError(code:message:)`` if the query fails.
    static func isPresent(in connection: SQLiteConnection) throws -> Bool {
        let stmt = try connection.prepare("SELECT 1 FROM meta WHERE key = ?")
        stmt.bind(metaVersionKey, at: 1)
        return try stmt.step()
    }

    /// Validates that this component's `meta` version row matches ``currentSchemaVersion``.
    ///
    /// - Parameter connection: The open connection to inspect.
    /// - Throws: ``PersistenceError/schemaVersionMismatch(found:expected:)`` for a different version,
    ///   ``PersistenceError/corruptData(_:)`` if the version row is unreadable, or
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

    // MARK: - Column values

    /// Names a column's kind as the file stores it.
    ///
    /// - Parameter values: The column's values.
    /// - Returns: `number`, `text` or `date`.
    static func kindName(of values: FigureColumn.Values) -> String {
        switch values {
        case .numbers: "number"
        case .text: "text"
        case .dates: "date"
        }
    }

    /// Encodes a column's values as a JSON array, which `jsonlite::fromJSON` reads directly.
    ///
    /// Missing values are `null`. JSON has no NaN or infinity, so those become `null` too.
    ///
    /// - Parameter values: The column's values.
    /// - Returns: The JSON text.
    /// - Throws: `EncodingError` if the values can't be encoded.
    static func encode(_ values: FigureColumn.Values) throws -> String {
        let encoder = JSONEncoder()
        let data: Data
        switch values {
        case .numbers(let numbers):
            data = try encoder.encode(numbers.map { number in number.flatMap { $0.isFinite ? $0 : nil } })
        case .text(let text):
            data = try encoder.encode(text)
        case .dates(let dates):
            data = try encoder.encode(dates.map { $0?.ISO8601Format() })
        }
        return String(decoding: data, as: UTF8.self)
    }

    /// Decodes a column's stored values.
    ///
    /// - Parameters:
    ///   - text: The JSON array.
    ///   - kind: The column's stored kind.
    /// - Returns: The values.
    /// - Throws: ``PersistenceError/corruptData(_:)`` for an unknown kind, unreadable JSON, or an invalid date.
    static func decode(_ text: String, kind: String) throws -> FigureColumn.Values {
        let decoder = JSONDecoder()
        let data = Data(text.utf8)
        do {
            switch kind {
            case "number":
                return .numbers(try decoder.decode([Double?].self, from: data))
            case "text":
                return .text(try decoder.decode([String?].self, from: data))
            case "date":
                let formatter = ISO8601DateFormatter()
                return .dates(try decoder.decode([String?].self, from: data).map { value in
                    guard let value else { return nil }
                    guard let date = formatter.date(from: value) else {
                        throw PersistenceError.corruptData("invalid date in a figure column: \(value)")
                    }
                    return date
                })
            default:
                throw PersistenceError.corruptData("unknown figure column kind: \(kind)")
            }
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.corruptData("unreadable \(kind) values in a figure column")
        }
    }
}
