//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopulationImportTests.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//
//  Verifies importPopulationTable against the real Data/arapat.csv sample
//  file, and importMicrosatTable (via a PopulationImportLayout-adjacent
//  GenotypeImportLayout) against Data/cornus.csv.
//

import Testing
import Foundation
@testable import PopulationGenetics

struct PopulationImportTests {

    /// Repo root, computed from this file's own location so tests don't
    /// depend on the CWD `swift test` happens to be invoked from.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // PopulationImportTests.swift -> PopulationGeneticsTests/
            .deletingLastPathComponent() // PopulationGeneticsTests/ -> Tests/
            .deletingLastPathComponent() // Tests/ -> repo root
    }

    private func loadDataFile(_ name: String) throws -> String {
        try String(contentsOf: Self.repoRoot.appendingPathComponent("Data").appendingPathComponent(name), encoding: .utf8)
    }

    // MARK: - arapat.csv (population/strata)

    private func importArapat() throws -> ImportedDataset {
        let csv = try loadDataFile("arapat.csv")
        return try importPopulationTable(csv: csv, layout: .init(
            strataColumns: ["Species", "Cluster", "Population"],
            nameColumn: "ID", latitudeColumn: "Latitude", longitudeColumn: "Longitude"
        ))
    }

    @Test func importsArapatIndividualsAndLoci() async throws {
        let dataset = try importArapat()

        #expect(dataset.matrix.individualCount == 363)
        #expect(dataset.matrix.locusCount == 8)
        #expect(Set(dataset.matrix.loci.map(\.name)) == Set(["LTRS", "WNT", "EN", "EF", "ZMP", "AML", "ATPS", "MP20"]))
    }

    @Test func importsArapatThreeLevelStrataHierarchy() async throws {
        let dataset = try importArapat()

        // 3 Species, 5 Clusters, 39 Populations (recounted directly from the file).
        let allReferences = dataset.strata.values.flatMap { $0 }
        let byLevel = Dictionary(grouping: allReferences, by: \.level)
        #expect(Set(byLevel["Species"]?.map(\.name) ?? []).count == 3)
        #expect(Set(byLevel["Cluster"]?.map(\.name) ?? []).count == 5)
        #expect(Set(byLevel["Population"]?.map(\.name) ?? []).count == 39)

        // Every individual carries all 3 levels.
        #expect(dataset.strata.count == dataset.matrix.individualCount)
        #expect(dataset.strata.values.allSatisfy { $0.count == 3 })
    }

    @Test func importsArapatSpatialCoordinates() async throws {
        let dataset = try importArapat()
        #expect(dataset.matrix.individuals.allSatisfy { $0.latitude != nil && $0.longitude != nil })
    }

    @Test func importsArapatUsesRealIndividualIDsAsNames() async throws {
        let dataset = try importArapat()
        #expect(dataset.matrix.individuals.contains { $0.name == "88_11A" })
    }

    // MARK: - cornus.csv (parentage), via the existing importMicrosatTable

    private func importCornus() throws -> ImportedDataset {
        let csv = try loadDataFile("cornus.csv")
        return try importMicrosatTable(csv: csv, layout: GenotypeImportLayout(
            familyColumn: "ID", offspringColumn: "OffID",
            latitudeColumn: "Latitude", longitudeColumn: "Longitude"
        ))
    }

    @Test func importsCornusIndividualsAndLoci() async throws {
        let dataset = try importCornus()

        #expect(dataset.matrix.individualCount == 62)
        #expect(dataset.matrix.locusCount == 5)
        #expect(Set(dataset.matrix.loci.map(\.name)) == Set(["G8", "H18", "N5", "N10", "O5"]))
    }

    @Test func importsCornusTwentyTwoMaternalFamilies() async throws {
        let dataset = try importCornus()
        #expect(dataset.parentage.families.count == 22)
    }

    @Test func importsCornusFamiliesWithFullOffspringSets() async throws {
        let dataset = try importCornus()

        for familyID in ["468", "474"] {
            let family = try #require(dataset.parentage.family(id: familyID))
            #expect(family.mother != nil)
            #expect(family.offspring.count == 20)
        }
    }

    @Test func importsCornusMotherOnlyFamilies() async throws {
        let dataset = try importCornus()
        let family = try #require(dataset.parentage.family(id: "226"))
        #expect(family.mother != nil)
        #expect(family.offspring.isEmpty)
    }
}
