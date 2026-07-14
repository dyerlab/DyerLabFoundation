//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2025 RJ Dyer.  All Rights Reserved.
//
//  ExtensionTests.swift
// PopulationGenetics
//
//  Created by Claude Code on 1/13/26.
//

import Testing
import CoreLocation
import Matrix
@testable import PopulationGenetics

struct ExtensionTests {

    // MARK: - Array+Individual Tests

    @Test func testIndividualCoordinatesExtraction() async throws {
        let ind1 = Individual(name: "Ind1", latitude: 37.7749, longitude: -122.4194)
        let ind2 = Individual(name: "Ind2", latitude: 40.7128, longitude: -74.0060)
        let ind3 = Individual(name: "Ind3") // No coordinates

        let individuals = [ind1, ind2, ind3]
        let coords = individuals.coordinates

        #expect(coords.count == 2) // Only ind1 and ind2 have coordinates
        #expect(coords[0].latitude == 37.7749)
        #expect(coords[0].longitude == -122.4194)
        #expect(coords[1].latitude == 40.7128)
        #expect(coords[1].longitude == -74.0060)
    }

    @Test func testIndividualCoordinatesWithNoSpatialData() async throws {
        let ind1 = Individual(name: "Ind1")
        let ind2 = Individual(name: "Ind2")

        let individuals = [ind1, ind2]
        let coords = individuals.coordinates

        #expect(coords.isEmpty)
    }

    @Test func testIndividualCoordinatesWithAllSpatial() async throws {
        let ind1 = Individual(name: "Ind1", latitude: 37.0, longitude: -122.0)
        let ind2 = Individual(name: "Ind2", latitude: 38.0, longitude: -123.0)
        let ind3 = Individual(name: "Ind3", latitude: 39.0, longitude: -124.0)

        let individuals = [ind1, ind2, ind3]
        let coords = individuals.coordinates

        #expect(coords.count == 3)
    }

    @Test func testIndividualPlacards() async throws {
        let ind1 = Individual(name: "Ind1", latitude: 37.0, longitude: -122.0)
        let ind2 = Individual(name: "Ind2", latitude: 38.0, longitude: -123.0)

        let individuals = [ind1, ind2]
        let placards = individuals.placards

        #expect(placards.count == 2)
        #expect(placards[0].title == "Ind1")
        #expect(placards[0].subtitle == "37.0000, -122.0000")
        #expect(placards[1].title == "Ind2")
        #expect(placards[1].subtitle == "38.0000, -123.0000")
    }

    @Test func testIndividualPlacardsWithNoSpatialData() async throws {
        let ind1 = Individual(name: "Ind1")
        let ind2 = Individual(name: "Ind2")

        let individuals = [ind1, ind2]
        let placards = individuals.placards

        #expect(placards.isEmpty) // No spatial data means no placards
    }

    @Test func testIndividualPlacardsWithRealData() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        let individuals = dataStore.fetchIndividuals()
        let placards = individuals.placards

        // Should have some placards from individuals with spatial data
        #expect(!placards.isEmpty)

        for placard in placards {
            #expect(!placard.title.isEmpty)
            #expect(!placard.subtitle.isEmpty)
        }
    }

    // MARK: - Integration Tests with Rarefaction Use Case
    //
    // Array.valueCounts() itself (renamed from histogram() when it moved to
    // Matrix — Array+Hashable.swift) now has its own dedicated coverage in
    // Matrix's ArrayHashableTests.swift; this integration test is the only
    // piece with genuine PopulationGenetics domain content (real allele
    // data), so it's the only one that stays here.

    @Test func testValueCountsWithAlleleData() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        let genotypes = dataStore.getGenotypesFor(locusName: "LTRS")
        try #require(!genotypes.isEmpty)

        // Extract all alleles (like rarefaction does)
        var alleles = genotypes.compactMap { $0.leftAllele }
        alleles.append(contentsOf: genotypes.compactMap { $0.rightAllele })

        let counts = alleles.valueCounts()

        #expect(!counts.isEmpty)
        #expect(counts.values.reduce(0.0, +) == Double(alleles.count))
    }

    // MARK: - Real Data Integration Tests

    @Test func testRealDataCoordinateExtraction() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        let individuals = dataStore.fetchIndividuals()
        let coords = individuals.coordinates

        // Should have some spatial individuals
        #expect(!coords.isEmpty)

        // Verify all coordinates are valid
        for coord in coords {
            #expect(coord.latitude >= -90 && coord.latitude <= 90)
            #expect(coord.longitude >= -180 && coord.longitude <= 180)
        }
    }

    @Test func testRealDataPlacardGeneration() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        // Get individuals from a specific stratum
        let stratum = dataStore.getStratum(named: "102", within: "Population")
        try #require(stratum != nil)

        let individuals = dataStore.getIndividuals(for: stratum!)
        let placards = individuals.placards

        for placard in placards {
            // Verify placard structure
            #expect(!placard.title.isEmpty)
            #expect(placard.subtitle.contains(","))
        }
    }
}
