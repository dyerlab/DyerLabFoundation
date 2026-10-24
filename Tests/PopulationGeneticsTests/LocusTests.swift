//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  LocusTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2026.01.13.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Testing
import Matrix
@testable import PopulationGenetics

@MainActor
struct LocusTests {

    // MARK: - Initialization Tests

    @Test func locusInitialization() async throws {
        let locus = Locus(name: "TestLocus", location: 12345, contig: "2")

        #expect(locus.name == "TestLocus")
        #expect(locus.location == 12345)
        #expect(locus.contig == "2")
        #expect(locus.alleleProvenance == .observed)
    }

    @Test func locusInitializationWithDefaults() async throws {
        let locus = Locus(name: "TestLocus")

        #expect(locus.name == "TestLocus")
        #expect(locus.location == 0)
        #expect(locus.contig == "")
    }

    @Test func locusInitializationWithRefAltPlaceholderProvenance() async throws {
        let locus = Locus(name: "SNP_1", contig: "dDocent_Contig_16", alleleProvenance: .refAltPlaceholder)

        #expect(locus.alleleProvenance == .refAltPlaceholder)
    }

    // MARK: - Genotype Frequencies Tests (via DataStore)

    @Test func genotypeFrequenciesProperty() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        let locus = dataStore.getLocus(named: "LTRS")
        try #require(locus != nil)

        let frequencies = dataStore.getGenotypeFrequencies(for: locus!)

        #expect(frequencies.N > 0)
        #expect(frequencies.A > 0)
        #expect(!frequencies.alleles.isEmpty)
    }

    @Test func genotypeFrequenciesWithMultipleAlleles() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        let locus = dataStore.getLocus(named: "MP20")
        try #require(locus != nil)

        let frequencies = dataStore.getGenotypeFrequencies(for: locus!)

        // MP20 should have multiple alleles in the test data
        #expect(frequencies.A >= 2.0)
        #expect(frequencies.alleles.count >= 2)
    }

    // MARK: - Sorting Tests

    @Test func locusSortingByContig() async throws {
        let locus1 = Locus(name: "Locus1", location: 100, contig: "1")
        let locus2 = Locus(name: "Locus2", location: 200, contig: "2")

        #expect(locus1 < locus2)
        #expect(!(locus2 < locus1))
    }

    @Test func locusSortingByLocation() async throws {
        let locus1 = Locus(name: "Locus1", location: 100, contig: "1")
        let locus2 = Locus(name: "Locus2", location: 200, contig: "1")

        #expect(locus1 < locus2)
        #expect(!(locus2 < locus1))
    }

    @Test func locusSortingPrioritizesContig() async throws {
        let locus1 = Locus(name: "Locus1", location: 300, contig: "1")
        let locus2 = Locus(name: "Locus2", location: 100, contig: "2")

        // Even though locus1 has higher location, contig takes precedence
        #expect(locus1 < locus2)
    }

    @Test func locusArraySorting() async throws {
        let locus1 = Locus(name: "C", location: 300, contig: "2")
        let locus2 = Locus(name: "A", location: 100, contig: "1")
        let locus3 = Locus(name: "B", location: 200, contig: "1")

        let sorted = [locus1, locus2, locus3].sorted()

        #expect(sorted[0] == locus2) // contig 1, location 100
        #expect(sorted[1] == locus3) // contig 1, location 200
        #expect(sorted[2] == locus1) // contig 2, location 300
    }

    @Test func locusArraySortingUsesNaturalNotLexicographicContigOrder() async throws {
        // Real contig names from ExampleData/phylog.012.pos. Plain lexicographic string
        // comparison would order these "Contig_105" < "Contig_16" < "Contig_2" <
        // "Contig_9" (comparing character-by-character); natural sort must not.
        let contig2 = Locus(name: "L2", contig: "dDocent_Contig_2")
        let contig9 = Locus(name: "L9", contig: "dDocent_Contig_9")
        let contig16 = Locus(name: "L16", contig: "dDocent_Contig_16")
        let contig105 = Locus(name: "L105", contig: "dDocent_Contig_105")

        let sorted = [contig105, contig16, contig2, contig9].sorted()

        #expect(sorted.map(\.name) == ["L2", "L9", "L16", "L105"])
    }

    // MARK: - Equality Tests

    @Test func locusEquality() async throws {
        let locus1 = Locus(name: "TestLocus")
        let locus2 = Locus(name: "TestLocus")

        // Different instances should not be equal (based on UUID)
        #expect(locus1 != locus2)
    }

    @Test func locusSelfEquality() async throws {
        let locus = Locus(name: "TestLocus")

        #expect(locus == locus)
    }

    // MARK: - Integration Tests with Real Data

    @Test func realDataLocusHasGenotypes() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        let loci = dataStore.getAllLoci()
        try #require(!loci.isEmpty)

        for locus in loci {
            let genotypes = dataStore.getGenotypes(for: locus)
            #expect(!genotypes.isEmpty, "Locus \(locus.name) should have genotypes")
        }
    }

    @Test func realDataLocusSorting() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        let loci = dataStore.getAllLoci()
        let sorted = loci.sorted()

        // Verify sorting is correct
        for i in 0..<(sorted.count - 1) {
            let current = sorted[i]
            let next = sorted[i + 1]

            if current.contig == next.contig {
                #expect(current.location <= next.location,
                       "\(current.name) location should be <= \(next.name) location")
            } else {
                #expect(current.contig.naturalCompare(next.contig) == .orderedAscending,
                       "\(current.name) contig should naturally sort before \(next.name) contig")
            }
        }
    }

    @Test func realDataLocusFrequencies() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        let loci = dataStore.getAllLoci()
        try #require(!loci.isEmpty)

        for locus in loci {
            let freq = dataStore.getGenotypeFrequencies(for: locus)

            // Basic sanity checks on frequencies
            #expect(freq.N > 0, "Locus \(locus.name) should have allele counts")
            #expect(freq.A > 0, "Locus \(locus.name) should have alleles")
            #expect(freq.He >= 0.0 && freq.He <= 1.0,
                   "He should be between 0 and 1 for \(locus.name)")
            #expect(freq.Ho >= 0.0 && freq.Ho <= 1.0,
                   "Ho should be between 0 and 1 for \(locus.name)")
        }
    }

    @Test func locusWithNoGenotypes() async throws {
        let store = PopGenStore()
        let locus = store.addLocus(name: "EmptyLocus")

        let frequencies = store.getGenotypeFrequencies(for: locus)

        #expect(frequencies.N == 0)
        #expect(frequencies.A == 0)
        #expect(frequencies.alleles.isEmpty)
    }
}
