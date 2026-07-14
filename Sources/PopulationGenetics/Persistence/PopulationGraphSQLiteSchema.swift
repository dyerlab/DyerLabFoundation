//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopulationGraphSQLiteSchema.swift
//  PopulationGenetics
//
//  Adds a single population graph, plus a generic analysis-results log, to
//  the same SQLite file as `GenotypeMatrixSQLiteSchema` — one project file
//  holds the genetic data and (optionally) the one graph derived from it, so
//  a simulation loop's "genotypes + graph per generation" stays as one file
//  instead of a pair that can drift apart.
//
//  Deliberately not a `graphs` (plural) table: this file holds at most one
//  graph. Multiple derived graphs (different strata levels, different
//  candidate constructions) get their own files.
//
//  `graph_loci` references `GenotypeMatrixSQLiteSchema`'s existing `loci`
//  table by ordinal rather than duplicating locus metadata — the graph's
//  loci are always a subset of this same file's genotype loci. As with that
//  schema, `REFERENCES` here documents intent; SQLite foreign keys are not
//  enforced (`PRAGMA foreign_keys` is never set), so referential integrity
//  is the encoder's responsibility, not the database's.
//
//  Versioned independently of the genotype schema via a `graph_schema_version`
//  row in the shared `meta` table, since `PRAGMA user_version` is already
//  spoken for by `GenotypeMatrixSQLiteSchema` and the two schemas can evolve
//  on separate timelines.
//

import Foundation

enum PopulationGraphSQLiteSchema {

    /// Bumped whenever the on-disk layout changes in a way that breaks
    /// existing readers. Tracked in `meta`, independent of the genotype
    /// schema's `PRAGMA user_version`.
    static let currentSchemaVersion: Int32 = 1

    static let metaVersionKey = "graph_schema_version"

    /// Assumes `meta` already exists (created by `GenotypeMatrixSQLiteSchema`).
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
        """
        CREATE TABLE results (
            ordinal     INTEGER PRIMARY KEY,
            uuid        TEXT NOT NULL UNIQUE,
            name        TEXT NOT NULL,
            description TEXT,
            body        TEXT NOT NULL,
            created_at  TEXT NOT NULL
        )
        """,
        """
        CREATE TABLE result_images (
            result_uuid TEXT NOT NULL REFERENCES results(uuid),
            name        TEXT NOT NULL,
            mime_type   TEXT NOT NULL,
            width       INTEGER,
            height      INTEGER,
            data        BLOB NOT NULL,
            PRIMARY KEY (result_uuid, name)
        )
        """,
    ]

    /// Creates every table for a freshly-opened database (after
    /// `GenotypeMatrixSQLiteSchema.createSchema` has already run) and
    /// records `graph_schema_version` in `meta`.
    static func createSchema(in connection: SQLiteConnection) throws {
        for statement in createStatements {
            try connection.execute(statement)
        }
        let stmt = try connection.prepare("INSERT INTO meta (key, value) VALUES (?, ?)")
        stmt.bind(metaVersionKey, at: 1)
        stmt.bind(String(currentSchemaVersion), at: 2)
        _ = try stmt.step()
    }

    /// Validates that an opened database's `graph_schema_version` meta row
    /// matches `currentSchemaVersion`, throwing `.schemaVersionMismatch` otherwise.
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
