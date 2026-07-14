//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeMatrixSQLiteSchema.swift
//  PopulationGenetics
//
//  The on-disk SQLite schema for a persisted `GenotypeMatrix`. Ordinals
//  (0-based array index) are the join key throughout, mirroring the in-memory
//  model exactly; UUIDs are stored only for identity round-trip, never as a
//  foreign key. This doubles as the authoritative byte-layout spec that any
//  non-Swift reader (e.g. the companion R script) must match:
//
//  - `genotype_blobs.blob_a`/`blob_b` for `biallelicSNP` loci hold the same
//    2-bit-packed, 4-genotypes-per-byte, LSB-first bytes as
//    `BiallelicColumn.packedBytes` (see that file for the exact bit layout);
//    `blob_b` is NULL.
//  - For `microsatellite` loci, `blob_a`/`blob_b` hold `leftAlleleBytes`/
//    `rightAlleleBytes` verbatim: one `UInt8` allele index per individual,
//    where index 0 means absent/missing.
//  - `codebooks` stores only the non-null allele labels (index 1...N); index
//    0 is always the implicit empty/NULL slot and is never written.
//  - `loci.allele_provenance == 'refAltPlaceholder'` marks loci whose codebook
//    holds `Z`/`z` placeholders (REF-slot/ALT-slot) rather than real bases,
//    e.g. loci imported from allele-anonymous sources like vcftools `--012`.
//  - `individual_strata` mirrors `node_strata` (see
//    `PopulationGraphSQLiteSchema.swift`) but keyed to `individuals(ordinal)`:
//    one row per (individual, level) pair, fully denormalized, no separate
//    strata table.
//

import Foundation

enum GenotypeMatrixSQLiteSchema {

    /// Bumped whenever the on-disk layout changes in a way that breaks
    /// existing readers.
    ///
    /// - `2`: `loci.contig` became `TEXT` (was `INTEGER`); added
    ///   `loci.allele_provenance` and the `individual_strata` table.
    static let currentSchemaVersion: Int32 = 2

    static let createStatements: [String] = [
        """
        CREATE TABLE meta (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
        """,
        """
        CREATE TABLE individuals (
            ordinal   INTEGER PRIMARY KEY,
            uuid      TEXT NOT NULL UNIQUE,
            name      TEXT NOT NULL,
            latitude  REAL,
            longitude REAL
        )
        """,
        """
        CREATE TABLE loci (
            ordinal           INTEGER PRIMARY KEY,
            uuid              TEXT NOT NULL UNIQUE,
            name              TEXT NOT NULL,
            contig            TEXT NOT NULL,
            location          INTEGER NOT NULL,
            marker_type       TEXT NOT NULL CHECK (marker_type IN ('biallelicSNP', 'microsatellite')),
            allele_provenance TEXT NOT NULL DEFAULT 'observed'
                CHECK (allele_provenance IN ('observed', 'refAltPlaceholder'))
        )
        """,
        """
        CREATE TABLE codebooks (
            locus_ordinal INTEGER NOT NULL REFERENCES loci(ordinal),
            allele_index  INTEGER NOT NULL,
            label         TEXT NOT NULL,
            PRIMARY KEY (locus_ordinal, allele_index)
        )
        """,
        """
        CREATE TABLE genotype_blobs (
            locus_ordinal    INTEGER PRIMARY KEY REFERENCES loci(ordinal),
            individual_count INTEGER NOT NULL,
            blob_a           BLOB NOT NULL,
            blob_b           BLOB
        )
        """,
        """
        CREATE TABLE individual_strata (
            individual_ordinal INTEGER NOT NULL REFERENCES individuals(ordinal),
            level              TEXT NOT NULL,
            stratum_uuid       TEXT NOT NULL,
            stratum_name       TEXT NOT NULL,
            PRIMARY KEY (individual_ordinal, level, stratum_uuid)
        )
        """,
        """
        CREATE TABLE families (
            family_id      TEXT PRIMARY KEY,
            family_order   INTEGER NOT NULL,
            mother_ordinal INTEGER REFERENCES individuals(ordinal)
        )
        """,
        """
        CREATE TABLE family_offspring (
            family_id         TEXT NOT NULL REFERENCES families(family_id),
            offspring_ordinal INTEGER NOT NULL REFERENCES individuals(ordinal),
            offspring_order   INTEGER NOT NULL,
            PRIMARY KEY (family_id, offspring_ordinal)
        )
        """,
    ]

    /// Creates every table for a freshly-opened, empty database and sets
    /// `PRAGMA user_version` to `currentSchemaVersion`.
    static func createSchema(in connection: SQLiteConnection) throws {
        for statement in createStatements {
            try connection.execute(statement)
        }
        try connection.setUserVersion(currentSchemaVersion)
    }

    /// Validates that an opened database's `user_version` matches
    /// `currentSchemaVersion`, throwing `.schemaVersionMismatch` otherwise.
    static func validateSchemaVersion(of connection: SQLiteConnection) throws {
        let found = try connection.userVersion()
        guard found == currentSchemaVersion else {
            throw PersistenceError.schemaVersionMismatch(found: found, expected: currentSchemaVersion)
        }
    }
}
