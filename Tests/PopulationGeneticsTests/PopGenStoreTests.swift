//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopGenStoreTests.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//
//  Exercises the PopGenStore facade standalone. See also PopGenStoreTest.swift
//  for the end-to-end regression test against the real arapat.csv import.
//

import Testing
import Foundation
@testable import PopulationGenetics

struct PopGenStoreTests {

    private func makeStore() -> PopGenStore {
        let store = PopGenStore()
        let a = store.addIndividual(name: "A", latitude: 37.5, longitude: -77.4)
        let b = store.addIndividual(name: "B", latitude: 38.0, longitude: -78.0)
        _ = store.addIndividual(name: "C")

        store.addLocus(name: "MP20")
        store.addLocus(name: "LTRS")

        store.setGenotype(individual: a, locusName: "MP20", leftAllele: "128", rightAllele: "130")
        store.setGenotype(individual: b, locusName: "MP20", leftAllele: "128", rightAllele: "128")
        store.setGenotype(individual: a, locusName: "LTRS", leftAllele: "01", rightAllele: "01")

        return store
    }

    // MARK: - Individuals

    @Test func addIndividualExtendsExistingLocusColumns() async throws {
        let store = PopGenStore()
        store.addLocus(name: "L1")
        let ind = store.addIndividual(name: "X")

        #expect(store.fetchIndividuals().count == 1)
        #expect(store.getGenotype(for: ind, locusName: "L1")?.isEmpty == true)
    }

    @Test func fetchIndividualsSortsNaturally() async throws {
        let store = PopGenStore()
        store.addIndividual(name: "9")
        store.addIndividual(name: "88")
        store.addIndividual(name: "12")

        #expect(store.fetchIndividuals().map(\.name) == ["9", "12", "88"])
    }

    @Test func deleteIndividualRemovesFromEveryLocusColumn() async throws {
        let store = makeStore()
        let a = store.fetchIndividuals().first { $0.name == "A" }!

        store.deleteIndividual(id: a.id)

        #expect(store.fetchIndividuals().count == 2)
        #expect(store.getIndividual(id: a.id) == nil)
        #expect(store.getGenotypesFor(locusName: "MP20").count == 2)
    }

    // MARK: - Loci / Genotypes

    @Test func setGenotypeRegistersAllelesAndRoundTrips() async throws {
        let store = makeStore()
        let a = store.fetchIndividuals().first { $0.name == "A" }!

        let geno = store.getGenotype(for: a, locusName: "MP20")
        #expect(geno?.leftAllele == "128")
        #expect(geno?.rightAllele == "130")
    }

    @Test func getGenotypesForLocusIncludesMissingEntries() async throws {
        let store = makeStore()
        // "C" never got an MP20 call.
        let genotypes = store.getGenotypesFor(locusName: "MP20")
        #expect(genotypes.count == 3)
        #expect(genotypes.filter(\.isEmpty).count == 1)
    }

    @Test func getLocusNamesOnlyReturnsLociWithACall() async throws {
        let store = makeStore()
        let a = store.fetchIndividuals().first { $0.name == "A" }!
        let c = store.fetchIndividuals().first { $0.name == "C" }!

        #expect(store.getLocusNames(for: a) == ["LTRS", "MP20"])
        #expect(store.getLocusNames(for: c).isEmpty)
    }

    // MARK: - Strata

    @Test func addStratumIsIdempotentPerNameAndLevel() async throws {
        let store = PopGenStore()
        let first = store.addStratum(name: "SBP", within: "Region")
        let second = store.addStratum(name: "SBP", within: "Region")

        #expect(first.id == second.id)
        #expect(store.getAllStrata().count == 1)
    }

    @Test func tagIndividualPopulatesBothDirections() async throws {
        let store = makeStore()
        let a = store.fetchIndividuals().first { $0.name == "A" }!
        let b = store.fetchIndividuals().first { $0.name == "B" }!
        let sbp = store.addStratum(name: "SBP", within: "Region")

        store.tagIndividual(a.id, with: sbp)
        store.tagIndividual(b.id, with: sbp)

        #expect(store.individualCount(for: sbp) == 2)
        #expect(Set(store.getIndividuals(for: sbp).map(\.name)) == Set(["A", "B"]))
        #expect(store.getStrata(for: a).map(\.name) == ["SBP"])
        #expect(store.getIndividualsWithinStratum(named: "SBP").count == 2)
    }

    @Test func getStrataWithinFiltersByLevelAndSortsNaturally() async throws {
        let store = PopGenStore()
        store.addStratum(name: "9", within: "Population")
        store.addStratum(name: "88", within: "Population")
        store.addStratum(name: "SBP", within: "Region")

        let populations = store.getStrataWithin(level: "Population")
        #expect(populations.map(\.name) == ["9", "88"])
    }

    // MARK: - Frequencies

    @Test func getFrequenciesForLocusReflectsRegisteredAlleles() async throws {
        let store = makeStore()
        let freq = store.getFrequenciesForLocus(locusName: "MP20")

        #expect(freq.alleles.sorted() == ["128", "130"])
        #expect(freq.count(for: "128") == 3) // A:128, A:130 (1 count for 128), B:128, B:128
    }

    // MARK: - Mating

    @Test func mateIndividualsProducesOffspringWithCombinedAlleles() async throws {
        let store = makeStore()
        let a = store.fetchIndividuals().first { $0.name == "A" }!
        let b = store.fetchIndividuals().first { $0.name == "B" }!

        let child = store.mateIndividuals(mother: a, father: b)

        #expect(store.fetchIndividuals().count == 4)
        let childGeno = store.getGenotype(for: child, locusName: "MP20")
        #expect(childGeno?.leftAllele == "128")
        #expect(["128", "130"].contains(childGeno?.rightAllele))
    }

    // MARK: - Matrix materialization

    @Test func matrixMaterializesMicrosatelliteColumns() async throws {
        let store = makeStore()
        let matrix = store.matrix

        #expect(matrix.individualCount == 3)
        #expect(matrix.locusCount == 2)
        #expect(matrix.columns[matrix.locusIndex(named: "MP20")!].markerType == .microsatellite)
    }

    @Test func matrixMaterializesBiallelicSNPColumns() async throws {
        let store = PopGenStore()
        let a = store.addIndividual(name: "A")
        let b = store.addIndividual(name: "B")
        store.addLocus(name: "snp1", markerType: .biallelicSNP)

        store.setGenotype(individual: a, locusName: "snp1", leftAllele: "Z", rightAllele: "Z")
        store.setGenotype(individual: b, locusName: "snp1", leftAllele: "Z", rightAllele: "z")

        let column = store.matrix.columns[0]
        #expect(column.markerType == .biallelicSNP)
        let allelesA = try #require(column.alleles(at: 0))
        let allelesB = try #require(column.alleles(at: 1))
        #expect(allelesA == (1, 1))
        #expect(allelesB == (1, 2))
    }

    // MARK: - Persistence

    @Test func saveAndLoadRoundTripsThroughSQLite() async throws {
        let store = makeStore()
        let sbp = store.addStratum(name: "SBP", within: "Region")
        let a = store.fetchIndividuals().first { $0.name == "A" }!
        store.tagIndividual(a.id, with: sbp)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".db")
        defer { try? FileManager.default.removeItem(at: url) }

        try await store.save(to: url, projectName: "test-project")
        let reloaded = try await PopGenStore.load(from: url)

        #expect(reloaded.fetchIndividuals().count == 3)
        #expect(reloaded.getAllLoci().count == 2)
        let reloadedA = reloaded.fetchIndividuals().first { $0.name == "A" }!
        #expect(reloaded.getGenotype(for: reloadedA, locusName: "MP20")?.leftAllele == "128")
        #expect(reloaded.getStrata(for: reloadedA).map(\.name) == ["SBP"])
    }
}
