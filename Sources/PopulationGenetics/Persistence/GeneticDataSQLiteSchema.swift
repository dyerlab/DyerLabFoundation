//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GeneticDataSQLiteSchema.swift
//  PopulationGenetics
//
//  The on-disk SQLite schema for the `.geneticData` component: individuals,
//  loci, genotypes, parentage. Ordinals (0-based array index) are the join
//  key throughout, mirroring the in-memory model exactly; UUIDs are stored
//  only for identity round-trip, never as a foreign key. This doubles as the
//  authoritative byte-layout spec that any non-Swift reader (e.g. the
//  companion R script) must match:
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
//  - `individual_strata` mirrors `node_strata` (see `GraphSQLiteSchema.swift`)
//    but keyed to `individuals(ordinal)`: one row per (individual, level)
//    pair, fully denormalized, no separate strata table.
//
//  Like every other component (see `StoreComponents.swift`), this one is
//  independently optional: a `ProjectStore` file can hold graph/results/log/
//  matrices data with no genetic data at all.
//

import Foundation

enum GeneticDataSchemaComponent {

    /// Bumped whenever the on-disk layout changes in a way that breaks
    /// existing readers. Tracked via the `genetic_data_schema_version` row in
    /// `meta`, whose mere presence signals this component exists in the file
    /// — not `PRAGMA user_version`, which can't express "this optional
    /// component is present" the way a per-component meta key can.
    static let currentSchemaVersion: Int32 = 1

    static let metaVersionKey = "genetic_data_schema_version"
    static let hasFlagKey = "has_genetic_data"

    static let createStatements: [String] = [
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

    /// Creates this component's tables and records its version + `has_genetic_data`
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
