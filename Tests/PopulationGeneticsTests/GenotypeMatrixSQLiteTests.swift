//
//  GenotypeMatrixSQLiteTests.swift
//  PopulationGenetics
//
//  Round-trip tests for the SQLite-backed GenotypeMatrixStore.
//

import Foundation
import Testing
@testable import PopulationGenetics

struct GenotypeMatrixSQLiteTests {

    /// Builds a 4-individual matrix with one biallelic SNP and one microsat locus.
    private func makeMatrix() -> GenotypeMatrix {
        let individuals = [
            Individual(name: "i0", latitude: 37.5, longitude: -77.4),
            Individual(name: "i1"),
            Individual(name: "i2", latitude: 38.1, longitude: -78.2),
            Individual(name: "i3"),
        ]

        let snpBook = AlleleCodebook(alleles: ["G", "A"])           // 1 = G, 2 = A
        // AA, AB, BB, missing
        let snp = BiallelicColumn(codebook: snpBook, codes: [1, 2, 3, 0])

        let msatBook = AlleleCodebook(alleles: ["142", "146", "150"]) // 1,2,3
        let msat = MultiallelicColumn(
            codebook: msatBook,
            left:  [1, 2, 1, 0],
            right: [1, 3, 2, 0]
        )

        let loci = [
            Locus(name: "snp1", location: 100, contig: "1"),
            Locus(name: "mp20", location: 0, contig: "0"),
        ]

        return GenotypeMatrix(individuals: individuals, loci: loci, columns: [snp, msat])
    }

    private func makeParentage() -> ParentageDesign {
        ParentageDesign(families: [
            MaternalFamily(id: "fam1", mother: 0, offspring: [1, 2]),
            MaternalFamily(id: "fam2", mother: nil, offspring: [3]),
        ])
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".db")
    }

    @Test func roundTripPreservesIndividualsAndLoci() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let original = makeMatrix()
        try await GenotypeMatrixStore.save(original, projectName: "test-project", to: url)
        let reloaded = try await GenotypeMatrixStore.load(from: url).matrix

        #expect(reloaded.individualCount == original.individualCount)
        #expect(reloaded.locusCount == original.locusCount)

        for i in 0..<original.individualCount {
            #expect(reloaded.individuals[i].id == original.individuals[i].id)
            #expect(reloaded.individuals[i].name == original.individuals[i].name)
            #expect(reloaded.individuals[i].latitude == original.individuals[i].latitude)
            #expect(reloaded.individuals[i].longitude == original.individuals[i].longitude)
        }

        for i in 0..<original.locusCount {
            #expect(reloaded.loci[i].id == original.loci[i].id)
            #expect(reloaded.loci[i].name == original.loci[i].name)
            #expect(reloaded.loci[i].contig == original.loci[i].contig)
            #expect(reloaded.loci[i].location == original.loci[i].location)
            #expect(reloaded.columns[i].markerType == original.columns[i].markerType)
        }
    }

    @Test func roundTripPreservesGenotypeCalls() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let original = makeMatrix()
        try await GenotypeMatrixStore.save(original, projectName: "test-project", to: url)
        let reloaded = try await GenotypeMatrixStore.load(from: url).matrix

        for locusIndex in 0..<original.locusCount {
            let originalColumn = original.columns[locusIndex]
            let reloadedColumn = reloaded.columns[locusIndex]
            for ordinal in 0..<original.individualCount {
                let originalAlleles = originalColumn.alleles(at: ordinal)
                let reloadedAlleles = reloadedColumn.alleles(at: ordinal)
                #expect(originalAlleles?.0 == reloadedAlleles?.0)
                #expect(originalAlleles?.1 == reloadedAlleles?.1)
                #expect(originalColumn.isEmpty(at: ordinal) == reloadedColumn.isEmpty(at: ordinal))
            }
        }
    }

    @Test func roundTripPreservesCodebookLabels() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let original = makeMatrix()
        try await GenotypeMatrixStore.save(original, projectName: "test-project", to: url)
        let reloaded = try await GenotypeMatrixStore.load(from: url).matrix

        for i in 0..<original.locusCount {
            #expect(reloaded.columns[i].codebook.labels == original.columns[i].codebook.labels)
        }
    }

    @Test func roundTripPreservesParentageDesign() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let matrix = makeMatrix()
        let parentage = makeParentage()
        try await GenotypeMatrixStore.save(matrix, parentage: parentage, projectName: "test-project", to: url)
        let reloaded = try await GenotypeMatrixStore.load(from: url).parentage

        #expect(reloaded.families.count == parentage.families.count)
        for i in 0..<parentage.families.count {
            #expect(reloaded.families[i].id == parentage.families[i].id)
            #expect(reloaded.families[i].mother == parentage.families[i].mother)
            #expect(reloaded.families[i].offspring == parentage.families[i].offspring)
        }
    }

    @Test func roundTripPreservesIndividualStrata() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let matrix = makeMatrix()
        let individualA = matrix.individuals[0]
        let individualC = matrix.individuals[2]

        let populationRef = StratumReference(level: "Population", name: "SBP")
        let regionRef = StratumReference(level: "Region", name: "North")

        let store = GenotypeMatrixStore()
        try await store.create(at: url, overwrite: true)
        try await store.write(matrix: matrix, strata: [individualA.id: [populationRef, regionRef]],
                               projectName: "test-project")
        await store.close()

        let reader = GenotypeMatrixStore()
        try await reader.open(at: url, mode: .readOnly)
        let dataset = try await reader.readDataset()
        let strataAgain = try await reader.readIndividualStrata()
        await reader.close()

        let reloadedStrata = dataset.strata[individualA.id] ?? []
        #expect(Set(reloadedStrata.map(\.name)) == Set(["SBP", "North"]))
        #expect(reloadedStrata.first(where: { $0.name == "SBP" })?.level == "Population")
        #expect(dataset.strata[individualC.id] == nil)
        #expect(strataAgain == dataset.strata)
    }

    @Test func roundTripPreservesAlleleProvenance() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let individuals = [Individual(name: "i0"), Individual(name: "i1")]
        let placeholderBook = AlleleCodebook(alleles: ["Z", "z"])
        let snp = BiallelicColumn(codebook: placeholderBook, codes: [1, 3])
        let loci = [Locus(name: "snp_anon", contig: "dDocent_Contig_16", alleleProvenance: .refAltPlaceholder)]
        let matrix = GenotypeMatrix(individuals: individuals, loci: loci, columns: [snp])

        try await GenotypeMatrixStore.save(matrix, projectName: "test-project", to: url)
        let reloaded = try await GenotypeMatrixStore.load(from: url).matrix

        #expect(reloaded.loci[0].alleleProvenance == .refAltPlaceholder)
        #expect(reloaded.columns[0].codebook.labels == ["", "Z", "z"])
    }

    @Test func readDatasetSynthesizesEmptyParentageWhenNoneStored() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        try await GenotypeMatrixStore.save(makeMatrix(), projectName: "test-project", to: url)
        let dataset = try await GenotypeMatrixStore.load(from: url)

        #expect(dataset.parentage.families.isEmpty)
    }

    @Test func openReadOnlyRejectsWrite() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        try await GenotypeMatrixStore.save(makeMatrix(), projectName: "test-project", to: url)

        let store = GenotypeMatrixStore()
        try await store.open(at: url, mode: .readOnly)
        await #expect(throws: PersistenceError.readOnly) {
            try await store.write(matrix: makeMatrix(), projectName: "test-project")
        }
        await store.close()
    }

    @Test func openRejectsMismatchedSchemaVersion() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        try await GenotypeMatrixStore.save(makeMatrix(), projectName: "test-project", to: url)

        // Corrupt the on-disk schema version directly.
        let connection = SQLiteConnection()
        try connection.open(at: url, mode: .readWrite)
        try connection.setUserVersion(GenotypeMatrixSQLiteSchema.currentSchemaVersion + 1)
        connection.close()

        let store = GenotypeMatrixStore()
        await #expect(throws: PersistenceError.self) {
            try await store.open(at: url, mode: .readOnly)
        }
    }
}
