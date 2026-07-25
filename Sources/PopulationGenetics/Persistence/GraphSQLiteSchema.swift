//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GraphSQLiteSchema.swift
//  PopulationGenetics
//
//  The on-disk schema for the `.graph` component. `nodes`, `node_values`,
//  `edges`, `edge_values`, and `graph_values` are domain-neutral — movable
//  as-is to a future generic `Persistence` target. `node_strata` and
//  `graph_loci` are genetics-specific extensions (population-strata lineage
//  on graph nodes; the subset of `.geneticData`'s `loci` a graph was built
//  from) and stay bundled here rather than splitting further, since a graph
//  in this store is nearly always genetics-derived even though `.geneticData`
//  itself is optional. SQLite never enforces the `REFERENCES loci(...)` FK
//  in this codebase (`PRAGMA foreign_keys` is never set), so creating this
//  component without `.geneticData` is harmless — `graph_loci` simply stays
//  empty, matching `writeGraph`'s `loci:` parameter defaulting to `[]`.
//
//  Deliberately not a `graphs` (plural) table: this component holds at most
//  one *current* graph — `writeGraph` replaces it in place, rather than
//  accumulating a history. Multiple derived graphs (different strata levels,
//  different candidate constructions) get their own files.
//

import Foundation

enum GraphSchemaComponent {

    /// Bumped whenever the on-disk layout changes in a way that breaks
    /// existing readers.
    static let currentSchemaVersion: Int32 = 1

    static let metaVersionKey = "graph_schema_version"
    static let hasFlagKey = "has_graph"

    static let createStatements: [String] = [
        """
        CREATE TABLE nodes (
            ordinal   INTEGER PRIMARY KEY,
            uuid      TEXT NOT NULL UNIQUE,
            name      TEXT NOT NULL,
            size      REAL NOT NULL,
            latitude  REAL CHECK (latitude  IS NULL OR latitude  BETWEEN -90  AND 90),
            longitude REAL CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
            CHECK ((latitude IS NULL) = (longitude IS NULL))
        )
        """,
        """
        CREATE TABLE node_strata (
            node_ordinal INTEGER NOT NULL REFERENCES nodes(ordinal),
            level        TEXT NOT NULL,
            stratum_uuid TEXT NOT NULL,
            stratum_name TEXT NOT NULL,
            PRIMARY KEY (node_ordinal, level, stratum_uuid)
        )
        """,
        """
        CREATE TABLE node_values (
            node_ordinal INTEGER NOT NULL REFERENCES nodes(ordinal),
            name         TEXT NOT NULL,
            value        REAL NOT NULL,
            kind         TEXT NOT NULL CHECK (kind IN ('intrinsic','extrinsic')),
            PRIMARY KEY (node_ordinal, name)
        )
        """,
        """
        CREATE TABLE edges (
            ordinal      INTEGER PRIMARY KEY,
            uuid         TEXT NOT NULL UNIQUE,
            from_ordinal INTEGER NOT NULL REFERENCES nodes(ordinal),
            to_ordinal   INTEGER NOT NULL REFERENCES nodes(ordinal),
            weight       REAL NOT NULL
        )
        """,
        """
        CREATE TABLE edge_values (
            edge_ordinal INTEGER NOT NULL REFERENCES edges(ordinal),
            name         TEXT NOT NULL,
            value        REAL NOT NULL,
            kind         TEXT NOT NULL CHECK (kind IN ('intrinsic','extrinsic')),
            PRIMARY KEY (edge_ordinal, name)
        )
        """,
        """
        CREATE TABLE graph_values (
            name  TEXT NOT NULL PRIMARY KEY,
            value REAL NOT NULL
        )
        """,
        """
        CREATE TABLE graph_loci (
            locus_ordinal INTEGER NOT NULL PRIMARY KEY REFERENCES loci(ordinal)
        )
        """,
    ]

    /// Creates this component's tables and records its version + `has_graph`
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
