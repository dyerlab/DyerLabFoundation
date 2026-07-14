//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeMatrixStore+Decoding.swift
//  PopulationGenetics
//
//  The read path: reconstructs in-memory `GenotypeMatrix`/`ParentageDesign`
//  values from the rows written by `GenotypeMatrixStore+Encoding`.
//

import Foundation

extension GenotypeMatrixStore {

    func decodeMatrix(connection: SQLiteConnection) throws -> GenotypeMatrix {
        let individuals = try readIndividuals(connection: connection)
        let locusRows = try readLoci(connection: connection)

        var loci: [Locus] = []
        var columns: [any GenotypeColumn] = []
        loci.reserveCapacity(locusRows.count)
        columns.reserveCapacity(locusRows.count)

        for (ordinal, row) in locusRows.enumerated() {
            let codebook = try readCodebook(locusOrdinal: ordinal, connection: connection)
            let column = try readColumn(locusOrdinal: ordinal, markerType: row.markerType,
                                         codebook: codebook, connection: connection)
            loci.append(row.locus)
            columns.append(column)
        }

        return GenotypeMatrix(individuals: individuals, loci: loci, columns: columns)
    }

    func decodeParentage(connection: SQLiteConnection) throws -> ParentageDesign? {
        let familyStmt = try connection.prepare("""
            SELECT family_id, mother_ordinal FROM families ORDER BY family_order
            """)
        var families: [MaternalFamily] = []
        while try familyStmt.step() {
            let familyID = familyStmt.columnText(at: 0)
            let mother = familyStmt.columnOptionalInt(at: 1)
            let offspring = try readOffspring(familyID: familyID, connection: connection)
            families.append(MaternalFamily(id: familyID, mother: mother, offspring: offspring))
        }
        return families.isEmpty ? nil : ParentageDesign(families: families)
    }

    // MARK: - Row readers

    private func readIndividuals(connection: SQLiteConnection) throws -> [Individual] {
        let stmt = try connection.prepare("""
            SELECT uuid, name, latitude, longitude FROM individuals ORDER BY ordinal
            """)
        var result: [Individual] = []
        while try stmt.step() {
            let uuidString = stmt.columnText(at: 0)
            guard let uuid = UUID(uuidString: uuidString) else {
                throw PersistenceError.corruptData("invalid individual uuid: \(uuidString)")
            }
            var individual = Individual(name: stmt.columnText(at: 1),
                                         latitude: stmt.columnOptionalDouble(at: 2),
                                         longitude: stmt.columnOptionalDouble(at: 3))
            individual.id = uuid
            result.append(individual)
        }
        return result
    }

    private func readLoci(connection: SQLiteConnection) throws -> [(locus: Locus, markerType: MarkerType)] {
        let stmt = try connection.prepare("""
            SELECT uuid, name, contig, location, marker_type, allele_provenance FROM loci ORDER BY ordinal
            """)
        var result: [(locus: Locus, markerType: MarkerType)] = []
        while try stmt.step() {
            let uuidString = stmt.columnText(at: 0)
            guard let uuid = UUID(uuidString: uuidString) else {
                throw PersistenceError.corruptData("invalid locus uuid: \(uuidString)")
            }
            let markerTypeString = stmt.columnText(at: 4)
            guard let markerType = MarkerType(rawValue: markerTypeString) else {
                throw PersistenceError.corruptData("invalid marker_type: \(markerTypeString)")
            }
            let provenanceString = stmt.columnText(at: 5)
            guard let provenance = Locus.AlleleProvenance(rawValue: provenanceString) else {
                throw PersistenceError.corruptData("invalid allele_provenance: \(provenanceString)")
            }
            var locus = Locus(name: stmt.columnText(at: 1),
                               location: UInt(stmt.columnInt(at: 3)),
                               contig: stmt.columnText(at: 2),
                               alleleProvenance: provenance)
            locus.id = uuid
            result.append((locus, markerType))
        }
        return result
    }

    /// Reads each individual's hierarchical stratum lineage. Mirrors
    /// `readNodeStrata` (`GenotypeMatrixStore+GraphDecoding.swift`).
    func readIndividualStrata(connection: SQLiteConnection) throws -> [UUID: [StratumReference]] {
        let individuals = try readIndividuals(connection: connection)
        let stmt = try connection.prepare("""
            SELECT individual_ordinal, level, stratum_uuid, stratum_name FROM individual_strata
            """)
        var result: [UUID: [StratumReference]] = [:]
        while try stmt.step() {
            let ordinal = stmt.columnInt(at: 0)
            guard individuals.indices.contains(ordinal) else {
                throw PersistenceError.corruptData("individual_strata references unknown individual ordinal \(ordinal)")
            }
            let level = stmt.columnText(at: 1)
            let uuidString = stmt.columnText(at: 2)
            guard let uuid = UUID(uuidString: uuidString) else {
                throw PersistenceError.corruptData("invalid stratum uuid: \(uuidString)")
            }
            let name = stmt.columnText(at: 3)
            result[individuals[ordinal].id, default: []].append(StratumReference(id: uuid, level: level, name: name))
        }
        return result
    }

    private func readCodebook(locusOrdinal: Int, connection: SQLiteConnection) throws -> AlleleCodebook {
        let stmt = try connection.prepare("""
            SELECT label FROM codebooks WHERE locus_ordinal = ? ORDER BY allele_index
            """)
        stmt.bind(locusOrdinal, at: 1)
        var labels: [String] = []
        while try stmt.step() {
            labels.append(stmt.columnText(at: 0))
        }
        return AlleleCodebook(alleles: labels)
    }

    private func readColumn(locusOrdinal: Int, markerType: MarkerType, codebook: AlleleCodebook,
                             connection: SQLiteConnection) throws -> any GenotypeColumn {
        let stmt = try connection.prepare("""
            SELECT individual_count, blob_a, blob_b FROM genotype_blobs WHERE locus_ordinal = ?
            """)
        stmt.bind(locusOrdinal, at: 1)
        guard try stmt.step() else {
            throw PersistenceError.corruptData("missing genotype_blobs row for locus ordinal \(locusOrdinal)")
        }
        let count = stmt.columnInt(at: 0)
        let blobA = stmt.columnBlob(at: 1)
        switch markerType {
        case .biallelicSNP:
            return BiallelicColumn(codebook: codebook, count: count, packedBytes: blobA)
        case .microsatellite:
            let blobB = stmt.columnBlob(at: 2)
            return MultiallelicColumn(codebook: codebook, left: blobA, right: blobB)
        }
    }

    private func readOffspring(familyID: String, connection: SQLiteConnection) throws -> [Int] {
        let stmt = try connection.prepare("""
            SELECT offspring_ordinal FROM family_offspring
            WHERE family_id = ? ORDER BY offspring_order
            """)
        stmt.bind(familyID, at: 1)
        var offspring: [Int] = []
        while try stmt.step() {
            offspring.append(stmt.columnInt(at: 0))
        }
        return offspring
    }
}
