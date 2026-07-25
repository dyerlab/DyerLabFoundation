//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ProjectStore+Encoding.swift
//  PopulationGenetics
//
//  Read/write access to the `.geneticData` component: turns in-memory
//  `GenotypeMatrix`/`ParentageDesign` values into rows in the schema defined
//  by `GeneticDataSQLiteSchema.swift`. Each helper prepares one statement and
//  reuses it across the row loop (reset + rebind) rather than re-preparing
//  SQL text per row, which matters once locus counts run into the
//  tens/hundreds of thousands.
//

import Foundation

extension ProjectStore {

    /// Writes the full genetic dataset into the currently open connection in
    /// one transaction, replacing any previously-written genetic data.
    /// Leaves every other component (graph/results/log/matrices) untouched.
    public func writeGeneticData(matrix: GenotypeMatrix, parentage: ParentageDesign? = nil,
                                  strata: [UUID: [StratumReference]] = [:]) async throws {
        guard mode == .readWrite else { throw PersistenceError.readOnly }
        try requireComponent(.geneticData, "geneticData")
        let connection = try requireConnection()
        try connection.beginTransaction()
        do {
            try deleteGeneticDataRows(connection: connection)
            try writeGeneticDataMeta(matrix: matrix, parentage: parentage, connection: connection)
            try writeIndividuals(matrix.individuals, connection: connection)
            try writeIndividualStrata(strata, individuals: matrix.individuals, connection: connection)
            try writeLoci(matrix: matrix, connection: connection)
            try writeCodebooksAndBlobs(matrix: matrix, connection: connection)
            try writeParentage(parentage, connection: connection)
            try connection.commit()
        } catch {
            try? connection.rollback()
            throw error
        }
    }

    /// Reconstructs the `GenotypeMatrix` from the currently open connection.
    public func readGeneticData() async throws -> GenotypeMatrix {
        try requireComponent(.geneticData, "geneticData")
        return try decodeMatrix(connection: try requireConnection())
    }

    /// Reconstructs the `ParentageDesign`, or `nil` if no families were stored.
    public func readParentage() async throws -> ParentageDesign? {
        try requireComponent(.geneticData, "geneticData")
        return try decodeParentage(connection: try requireConnection())
    }

    /// Reconstructs each individual's hierarchical stratum lineage, keyed by
    /// `Individual.id`. Empty if no strata were stored.
    public func readIndividualStrata() async throws -> [UUID: [StratumReference]] {
        try requireComponent(.geneticData, "geneticData")
        return try readIndividualStrata(connection: try requireConnection())
    }

    /// Reconstructs the full `ImportedDataset`, synthesizing an empty
    /// `ParentageDesign` when none was stored.
    public func readDataset() async throws -> ImportedDataset {
        try requireComponent(.geneticData, "geneticData")
        let connection = try requireConnection()
        let matrix = try decodeMatrix(connection: connection)
        let parentage = try decodeParentage(connection: connection) ?? ParentageDesign(families: [])
        let strata = try readIndividualStrata(connection: connection)
        return ImportedDataset(matrix: matrix, parentage: parentage, strata: strata)
    }

    // MARK: - Write helpers

    /// Flips a boolean classification flag in `meta` (e.g. `has_graph`,
    /// `has_results`), seeded to `"false"` by each component's own
    /// `createSchema`. Shared by `writeGraph`/`addResult`/`appendLog`/`addMatrix`.
    func setMetaFlag(_ key: String, to value: Bool, connection: SQLiteConnection) throws {
        let stmt = try connection.prepare("UPDATE meta SET value = ? WHERE key = ?")
        stmt.bind(value ? "true" : "false", at: 1)
        stmt.bind(key, at: 2)
        _ = try stmt.step()
    }

    /// Clears every row this component owns, so `writeGeneticData` can be
    /// called again on an already-populated connection without hitting the
    /// tables' primary keys.
    private func deleteGeneticDataRows(connection: SQLiteConnection) throws {
        for table in ["family_offspring", "families", "individual_strata", "genotype_blobs",
                      "codebooks", "loci", "individuals"] {
            try connection.execute("DELETE FROM \(table)")
        }
    }

    private func writeGeneticDataMeta(matrix: GenotypeMatrix, parentage: ParentageDesign?,
                                       connection: SQLiteConnection) throws {
        let markerTypes = Set(matrix.columns.map(\.markerType))
        let markerComposition: DatasetSummary.MarkerComposition
        switch markerTypes.count {
        case 0: markerComposition = .none
        case 1: markerComposition = DatasetSummary.MarkerComposition(rawValue: markerTypes.first!.rawValue) ?? .mixed
        default: markerComposition = .mixed
        }

        let stmt = try connection.prepare("INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)")
        let rows: [(String, String)] = [
            ("individual_count", String(matrix.individualCount)),
            ("locus_count", String(matrix.locusCount)),
            ("marker_composition", markerComposition.rawValue),
            ("has_parentage", (parentage?.families.isEmpty == false) ? "true" : "false"),
            (GeneticDataSchemaComponent.hasFlagKey, "true"),
        ]
        for (key, value) in rows {
            stmt.reset()
            stmt.bind(key, at: 1)
            stmt.bind(value, at: 2)
            _ = try stmt.step()
        }
    }

    func writeIndividuals(_ individuals: [Individual], connection: SQLiteConnection) throws {
        let stmt = try connection.prepare("""
            INSERT INTO individuals (ordinal, uuid, name, latitude, longitude)
            VALUES (?, ?, ?, ?, ?)
            """)
        for (ordinal, individual) in individuals.enumerated() {
            stmt.reset()
            stmt.bind(ordinal, at: 1)
            stmt.bind(individual.id.uuidString, at: 2)
            stmt.bind(individual.name, at: 3)
            stmt.bindOptional(individual.latitude, at: 4)
            stmt.bindOptional(individual.longitude, at: 5)
            _ = try stmt.step()
        }
    }

    /// Writes each individual's hierarchical stratum lineage. Mirrors
    /// `writeNodeStrata` (`ProjectStore+GraphEncoding.swift`), but builds its
    /// own ordinal map locally since `writeIndividuals` already establishes
    /// ordinal == array index and callers don't otherwise have one to pass in.
    func writeIndividualStrata(_ strata: [UUID: [StratumReference]], individuals: [Individual],
                                connection: SQLiteConnection) throws {
        guard !strata.isEmpty else { return }
        let ordinals = Dictionary(uniqueKeysWithValues: individuals.enumerated().map { ($1.id, $0) })
        let stmt = try connection.prepare("""
            INSERT INTO individual_strata (individual_ordinal, level, stratum_uuid, stratum_name)
            VALUES (?, ?, ?, ?)
            """)
        for (individualID, references) in strata {
            guard let ordinal = ordinals[individualID] else {
                throw PersistenceError.corruptData(
                    "individual_strata references an individual not present in this matrix")
            }
            for reference in references {
                stmt.reset()
                stmt.bind(ordinal, at: 1)
                stmt.bind(reference.level, at: 2)
                stmt.bind(reference.id.uuidString, at: 3)
                stmt.bind(reference.name, at: 4)
                _ = try stmt.step()
            }
        }
    }

    func writeLoci(matrix: GenotypeMatrix, connection: SQLiteConnection) throws {
        let stmt = try connection.prepare("""
            INSERT INTO loci (ordinal, uuid, name, contig, location, marker_type, allele_provenance)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """)
        for (ordinal, locus) in matrix.loci.enumerated() {
            let markerType = matrix.columns[ordinal].markerType
            stmt.reset()
            stmt.bind(ordinal, at: 1)
            stmt.bind(locus.id.uuidString, at: 2)
            stmt.bind(locus.name, at: 3)
            stmt.bind(locus.contig, at: 4)
            stmt.bind(Int(locus.location), at: 5)
            stmt.bind(markerType.rawValue, at: 6)
            stmt.bind(locus.alleleProvenance.rawValue, at: 7)
            _ = try stmt.step()
        }
    }

    func writeCodebooksAndBlobs(matrix: GenotypeMatrix, connection: SQLiteConnection) throws {
        let codebookStmt = try connection.prepare("""
            INSERT INTO codebooks (locus_ordinal, allele_index, label) VALUES (?, ?, ?)
            """)
        let blobStmt = try connection.prepare("""
            INSERT INTO genotype_blobs (locus_ordinal, individual_count, blob_a, blob_b)
            VALUES (?, ?, ?, ?)
            """)

        for (ordinal, column) in matrix.columns.enumerated() {
            let codebook = column.codebook
            for index in codebook.alleleIndices {
                codebookStmt.reset()
                codebookStmt.bind(ordinal, at: 1)
                codebookStmt.bind(Int(index), at: 2)
                codebookStmt.bind(codebook.label(for: index), at: 3)
                _ = try codebookStmt.step()
            }

            blobStmt.reset()
            blobStmt.bind(ordinal, at: 1)
            blobStmt.bind(column.count, at: 2)
            switch column {
            case let snp as BiallelicColumn:
                blobStmt.bind(snp.packedBytes, at: 3)
                blobStmt.bindNull(at: 4)
            case let msat as MultiallelicColumn:
                blobStmt.bind(msat.leftAlleleBytes, at: 3)
                blobStmt.bind(msat.rightAlleleBytes, at: 4)
            default:
                throw PersistenceError.corruptData(
                    "unsupported GenotypeColumn concrete type at locus ordinal \(ordinal)")
            }
            _ = try blobStmt.step()
        }
    }

    func writeParentage(_ parentage: ParentageDesign?, connection: SQLiteConnection) throws {
        guard let parentage else { return }
        let familyStmt = try connection.prepare("""
            INSERT INTO families (family_id, family_order, mother_ordinal) VALUES (?, ?, ?)
            """)
        let offspringStmt = try connection.prepare("""
            INSERT INTO family_offspring (family_id, offspring_ordinal, offspring_order) VALUES (?, ?, ?)
            """)
        for (order, family) in parentage.families.enumerated() {
            familyStmt.reset()
            familyStmt.bind(family.id, at: 1)
            familyStmt.bind(order, at: 2)
            familyStmt.bindOptional(family.mother, at: 3)
            _ = try familyStmt.step()

            for (offspringOrder, offspringOrdinal) in family.offspring.enumerated() {
                offspringStmt.reset()
                offspringStmt.bind(family.id, at: 1)
                offspringStmt.bind(offspringOrdinal, at: 2)
                offspringStmt.bind(offspringOrder, at: 3)
                _ = try offspringStmt.step()
            }
        }
    }
}
