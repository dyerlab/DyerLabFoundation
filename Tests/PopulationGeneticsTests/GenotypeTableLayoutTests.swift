//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeTableLayoutTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2026.11.01.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Testing
import Foundation
@testable import PopulationGenetics

struct GenotypeTableLayoutTests {

    // MARK: - Header detection

    @Test func populationIsTheInnermostPartitionAfterLargerGroupings() {
        let layout = GenotypeTableLayout(header: ["Species", "Cluster", "Population", "ID",
                                                  "Latitude", "Longitude", "LTRS", "WNT"])
        #expect(layout.partitionColumns == ["Species", "Cluster", "Population"])
        #expect(layout.idColumn == "ID")
        #expect(layout.latitudeColumn == "Latitude")
        #expect(layout.longitudeColumn == "Longitude")
        #expect(layout.locusColumns == ["LTRS", "WNT"])
        #expect(layout.unassignedColumns.isEmpty)
        #expect(!layout.isParentOffspring)
    }

    @Test func idIsOptionalForAdults() {
        let layout = GenotypeTableLayout(header: ["Population", "L01", "L02"])
        #expect(layout.partitionColumns == ["Population"])
        #expect(layout.idColumn == nil)
        #expect(layout.locusColumns == ["L01", "L02"])
    }

    @Test func siteAndLocaleNameThePopulationColumn() {
        #expect(GenotypeTableLayout(header: ["Region", "Site", "A"]).partitionColumns == ["Region", "Site"])
        #expect(GenotypeTableLayout(header: ["Locale", "A"]).partitionColumns == ["Locale"])
    }

    @Test(arguments: ["Offspring", "OffID", "OffspringID", "Offspring ID", "Off_ID", "off"])
    func offspringColumnSpellingsMakeAParentOffspringTable(name: String) {
        let layout = GenotypeTableLayout(header: ["ID", name, "Longitude", "Latitude", "G8"])
        #expect(layout.offspringColumn == name)
        #expect(layout.isParentOffspring)
        #expect(layout.locusColumns == ["G8"])
    }

    @Test func columnsBetweenPopulationAndLociAreUnassigned() {
        let layout = GenotypeTableLayout(header: ["Population", "Habitat", "Latitude", "Longitude", "A"])
        #expect(layout.partitionColumns == ["Population"])
        #expect(layout.unassignedColumns == ["Habitat"])
        #expect(layout.locusColumns == ["A"])
    }

    @Test func aSecondColumnForTheSameRoleIsUnassigned() {
        let layout = GenotypeTableLayout(header: ["Population", "Lat", "Latitude", "Longitude", "A"])
        #expect(layout.latitudeColumn == "Lat")
        #expect(layout.unassignedColumns == ["Latitude"])
    }

    @Test func aHeaderOfOnlyLociHasNoMetadata() {
        let layout = GenotypeTableLayout(header: ["A", "B"])
        #expect(layout.partitionColumns.isEmpty)
        #expect(layout.locusColumns == ["A", "B"])
    }

    @Test func emptyCSVThrows() {
        #expect(throws: GenotypeImportError.emptyInput) { try GenotypeTableLayout(csv: "") }
    }

    @Test func parentOffspringWithoutIDThrows() {
        let layout = GenotypeTableLayout(header: ["Population", "Offspring", "A"])
        #expect(throws: GenotypeImportError.missingColumn("ID")) { try layout.parentageLayout() }
    }

    // MARK: - Importing

    @Test func importsArapatAsAdultsWithThreePartitionLevels() throws {
        let csv = try ExampleData.text("arapat", extension: "csv")
        let layout = try GenotypeTableLayout(csv: csv)
        let dataset = try layout.importTable(csv: csv)

        #expect(dataset.matrix.individualCount == 363)
        #expect(dataset.matrix.locusCount == 8)
        #expect(dataset.parentage.families.isEmpty)
        #expect(dataset.strata.values.allSatisfy { $0.map(\.level) == ["Species", "Cluster", "Population"] })
    }

    @Test func importsCornusAsParentOffspring() throws {
        let csv = try ExampleData.text("cornus", extension: "csv")
        let layout = try GenotypeTableLayout(csv: csv)
        #expect(layout.offspringColumn == "OffID")

        let dataset = try layout.importTable(csv: csv)
        #expect(dataset.matrix.individualCount == 62)
        #expect(dataset.matrix.locusCount == 5)
        #expect(dataset.parentage.families.count == 22)
        #expect(dataset.parentage.families.allSatisfy { $0.mother != nil })
    }

    @Test func importsParentOffspringPopulationsAndSpreadsheetMotherMarkers() throws {
        let csv = """
            Population,ID,Offspring,A
            North,F1,0.0,1:2
            North,F1,1,1:1
            South,F2,00,2:2
            South,F2,1,2:3
            """
        let dataset = try GenotypeTableLayout(csv: csv).importTable(csv: csv)

        #expect(dataset.matrix.locusCount == 1)
        #expect(dataset.parentage.families.map(\.mother) == [0, 2])
        #expect(dataset.parentage.families.map(\.offspring) == [[1], [3]])
        let populations = dataset.matrix.individuals.map { dataset.strata[$0.id]?.last?.name }
        #expect(populations == ["North", "North", "South", "South"])
        #expect(dataset.matrix.individuals.map(\.name) == ["F1", "F1_1", "F2", "F2_1"])
    }
}
