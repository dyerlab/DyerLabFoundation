//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DatasetEditingTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2026.10.23.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
import PresentationZen
@testable import PopulationGenetics

struct DatasetEditingTests {

    @Test func settingAllelesRegistersNewAlleleAndLeavesOthersAlone() throws {
        var dataset = try TestData.dataset(TestData.exampleCSV())
        let before = dataset.alleleLabels(at: 1, locus: 0)

        let accepted = dataset.setAlleles(("01", "07"), at: 0, locus: 0)

        #expect(accepted)

        let edited = try #require(dataset.alleleLabels(at: 0, locus: 0))
        #expect(edited == ("01", "07"))
        #expect(dataset.alleleLabels(at: 1, locus: 0)?.0 == before?.0)
        #expect(dataset.alleleLabels(at: 1, locus: 0)?.1 == before?.1)
        #expect(dataset.matrix.individualCount == 2500)
    }

    @Test func clearingAllelesMakesGenotypeMissing() throws {
        var dataset = try TestData.dataset(TestData.exampleCSV())
        let accepted = dataset.setAlleles(nil, at: 5, locus: 3)
        #expect(accepted)
        #expect(dataset.alleleLabels(at: 5, locus: 3) == nil)
    }

    @Test func renamingToExistingPopulationReusesItsStratum() throws {
        var dataset = try TestData.dataset(TestData.exampleCSV())
        let pop02 = dataset.matrix.individuals.indices.first { dataset.populationName(at: $0) == "Pop02" }!
        let pop02Stratum = dataset.strata[dataset.matrix.individuals[pop02].id]?.last

        dataset.setPopulationName("Pop02", at: 0)

        #expect(dataset.populationName(at: 0) == "Pop02")
        #expect(dataset.strata[dataset.matrix.individuals[0].id]?.last == pop02Stratum)
    }

    @Test func settingCoordinatesChangesOnlyThatIndividual() throws {
        var dataset = try TestData.dataset(TestData.exampleCSV())
        let neighbour = dataset.matrix.individuals[1]

        dataset.setLatitude(36.5, at: 0)
        dataset.setLongitude(nil, at: 0)

        #expect(dataset.matrix.individuals[0].latitude == 36.5)
        #expect(dataset.matrix.individuals[0].longitude == nil)
        #expect(dataset.matrix.individuals[1] == neighbour)
    }
}
