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
//  IndividualTests.swift
// PopulationGenetics
//
//  Created by Claude Code on 1/13/26.
//

import Testing
import CoreLocation
import Matrix
@testable import PopulationGenetics

struct IndividualTests {

    // MARK: - Initialization Tests

    @Test func testIndividualInitialization() async throws {
        let ind = Individual(name: "Test001", latitude: 37.7749, longitude: -122.4194)

        #expect(ind.name == "Test001")
        #expect(ind.latitude == 37.7749)
        #expect(ind.longitude == -122.4194)
    }

    @Test func testIndividualInitializationWithoutCoordinates() async throws {
        let ind = Individual(name: "Test002")

        #expect(ind.name == "Test002")
        #expect(ind.latitude == nil)
        #expect(ind.longitude == nil)
    }

    // MARK: - Spatial Property Tests

    @Test func testIsSpatialWithCoordinates() async throws {
        let ind = Individual(name: "Test003", latitude: 37.7749, longitude: -122.4194)
        #expect(ind.isSpatial == true)
    }

    @Test func testIsSpatialWithoutCoordinates() async throws {
        let ind = Individual(name: "Test004")
        #expect(ind.isSpatial == false)
    }

    @Test func testIsSpatialWithPartialCoordinates() async throws {
        let ind1 = Individual(name: "Test005", latitude: 37.7749, longitude: nil)
        #expect(ind1.isSpatial == false)

        let ind2 = Individual(name: "Test006", latitude: nil, longitude: -122.4194)
        #expect(ind2.isSpatial == false)
    }

    @Test func testCoordinateProperty() async throws {
        let ind = Individual(name: "Test007", latitude: 37.7749, longitude: -122.4194)

        let coord = ind.coordinate
        try #require(coord != nil)
        #expect(coord!.latitude == 37.7749)
        #expect(coord!.longitude == -122.4194)
    }

    @Test func testCoordinatePropertyWithoutCoordinates() async throws {
        let ind = Individual(name: "Test008")
        #expect(ind.coordinate == nil)
    }

    // MARK: - Genotype Retrieval Tests (via PopGenStore)

    @Test func testGetGenotypeByName() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        let individuals = dataStore.fetchIndividuals()
        try #require(!individuals.isEmpty)

        let ind = individuals.first!
        let locusNames = dataStore.getLocusNames(for: ind)

        if let firstLocusName = locusNames.first {
            let geno = dataStore.getGenotype(for: ind, locusName: firstLocusName)
            #expect(geno != nil)
        }
    }

    @Test func testGetGenotypeNonexistentLocus() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        let individuals = dataStore.fetchIndividuals()
        try #require(!individuals.isEmpty)

        let ind = individuals.first!
        let geno = dataStore.getGenotype(for: ind, locusName: "NONEXISTENT_LOCUS")
        #expect(geno == nil)
    }

    // MARK: - Locus Names Tests

    @Test func testLocusNames() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        let individuals = dataStore.fetchIndividuals()
        try #require(!individuals.isEmpty)

        let ind = individuals.first!
        let locusNames = dataStore.getLocusNames(for: ind)

        #expect(!locusNames.isEmpty)

        // Should be naturally sorted
        #expect(locusNames == locusNames.naturalSorted())
    }

    // MARK: - Mating Tests (via PopGenStore)

    @Test func testMatingProducesOffspring() async throws {
        let store = PopGenStore()
        store.addLocus(name: "TestLocus")
        let mother = store.addIndividual(name: "Mom", latitude: 37.0, longitude: -122.0)
        let father = store.addIndividual(name: "Dad", latitude: 38.0, longitude: -123.0)
        store.setGenotype(individual: mother, locusName: "TestLocus", leftAllele: "A", rightAllele: "A")
        store.setGenotype(individual: father, locusName: "TestLocus", leftAllele: "B", rightAllele: "B")

        let offspring = store.mateIndividuals(mother: mother, father: father)

        #expect(offspring.name == "Mom:Dad")
        #expect(offspring.latitude == mother.latitude)
        #expect(offspring.longitude == mother.longitude)
        #expect(store.getGenotype(for: offspring, locusName: "TestLocus")?.isEmpty == false)
    }

    @Test func testMatingInheritsGenotypes() async throws {
        let testStore = PopGenStore()

        testStore.addLocus(name: "TestLocus")

        let mother = testStore.addIndividual(name: "Mom", latitude: 37.0, longitude: -122.0)
        let father = testStore.addIndividual(name: "Dad", latitude: 37.0, longitude: -122.0)

        testStore.setGenotype(individual: mother, locusName: "TestLocus", leftAllele: "A", rightAllele: "A")
        testStore.setGenotype(individual: father, locusName: "TestLocus", leftAllele: "B", rightAllele: "B")

        let offspring = testStore.mateIndividuals(mother: mother, father: father)

        let offspringGenotypes = testStore.getGenotypes(for: offspring).filter { !$0.isEmpty }
        #expect(offspringGenotypes.count == 1)

        let offspringGeno = offspringGenotypes.first
        try #require(offspringGeno != nil)

        // Should be A/B heterozygote
        #expect(offspringGeno!.leftAllele == "A" || offspringGeno!.leftAllele == "B")
        #expect(offspringGeno!.rightAllele == "A" || offspringGeno!.rightAllele == "B")
    }

    // MARK: - Parentage Assignment Tests (via PopGenStore)

    @Test func testPullParentAssignsLineage() async throws {
        let testStore = PopGenStore()

        testStore.addLocus(name: "TestLocus")

        let mother = testStore.addIndividual(name: "Mom")
        let offspring = testStore.addIndividual(name: "Offspring")

        testStore.setGenotype(individual: mother, locusName: "TestLocus", leftAllele: "A", rightAllele: "B")
        testStore.setGenotype(individual: offspring, locusName: "TestLocus", leftAllele: "A", rightAllele: "C")

        testStore.pullParent(for: offspring, from: mother, isMom: true)

        let offGeno = testStore.getGenotype(for: offspring, locusName: "TestLocus")
        try #require(offGeno != nil)

        // Lineage should be set after pulling parent
        #expect(offGeno!.leftLineage != Genotype.UnknownLineage ||
               offGeno!.rightLineage != Genotype.UnknownLineage)
    }

    @Test func testPullParentWithFather() async throws {
        let testStore = PopGenStore()

        testStore.addLocus(name: "TestLocus")

        let father = testStore.addIndividual(name: "Dad")
        let offspring = testStore.addIndividual(name: "Offspring")

        testStore.setGenotype(individual: father, locusName: "TestLocus", leftAllele: "A", rightAllele: "B")
        testStore.setGenotype(individual: offspring, locusName: "TestLocus", leftAllele: "A", rightAllele: "C")

        testStore.pullParent(for: offspring, from: father, isMom: false)

        let offGeno = testStore.getGenotype(for: offspring, locusName: "TestLocus")
        try #require(offGeno != nil)

        // Should set paternal lineage
        #expect(offGeno!.leftLineage == Genotype.PaternalLineage ||
               offGeno!.rightLineage == Genotype.PaternalLineage)
    }

    // MARK: - Integration Tests with Real Data

    @Test func testRealDataIndividualHasValidGenotypes() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        let individuals = dataStore.fetchIndividuals()
        try #require(!individuals.isEmpty)

        let ind = individuals.first!
        let genotypes = dataStore.getGenotypes(for: ind)

        #expect(!genotypes.isEmpty)
    }

    @Test func testRealDataIndividualSpatialProperties() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        let individuals = dataStore.fetchIndividuals()

        var spatialCount = 0
        for ind in individuals {
            if ind.isSpatial {
                spatialCount += 1
                #expect(ind.coordinate != nil)
                #expect(ind.latitude != nil)
                #expect(ind.longitude != nil)
            }
        }

        // Should have some spatial individuals in preview data
        #expect(spatialCount > 0)
    }
}
