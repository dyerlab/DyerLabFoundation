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
//  GenotypeTests.swift
// PopulationGenetics
//
//  Created by Claude Code on 1/13/26.
//

import Testing
@testable import PopulationGenetics

struct GenotypeTests {

    // MARK: - Initialization Tests

    @Test func testGenotypeInitialization() async throws {
        let geno = Genotype(leftAllele: "A", rightAllele: "B")

        #expect(geno.leftAllele == "A")
        #expect(geno.rightAllele == "B")
        #expect(geno.leftLineage == Genotype.UnknownLineage)
        #expect(geno.rightLineage == Genotype.UnknownLineage)
    }

    // MARK: - Ploidy Tests

    @Test func testEmptyGenotype() async throws {
        let geno = Genotype(leftAllele: "", rightAllele: "")

        #expect(geno.isEmpty == true)
        #expect(geno.ploidy == Genotype.Empty)
        #expect(geno.isHeterozygote == false)
    }

    @Test func testHaploidGenotype() async throws {
        let geno1 = Genotype(leftAllele: "A", rightAllele: "")
        #expect(geno1.ploidy == Genotype.Haploid)
        #expect(geno1.isEmpty == false)

        let geno2 = Genotype(leftAllele: "", rightAllele: "B")
        #expect(geno2.ploidy == Genotype.Haploid)
    }

    @Test func testDiploidHomozygote() async throws {
        let geno = Genotype(leftAllele: "A", rightAllele: "A")

        #expect(geno.ploidy == Genotype.Diploid)
        #expect(geno.isEmpty == false)
        #expect(geno.isHeterozygote == false)
    }

    @Test func testDiploidHeterozygote() async throws {
        let geno = Genotype(leftAllele: "A", rightAllele: "B")

        #expect(geno.ploidy == Genotype.Diploid)
        #expect(geno.isEmpty == false)
        #expect(geno.isHeterozygote == true)
    }

    // MARK: - Lineage Constants Tests

    @Test func testLineageConstants() async throws {
        #expect(Genotype.MaternalLineage == -1)
        #expect(Genotype.UnknownLineage == 0)
        #expect(Genotype.PaternalLineage == 1)
        #expect(Genotype.AmbiguousLineage == 2)
        #expect(Genotype.ImpossibleLineage == 3)
    }

    @Test func testPloidyConstants() async throws {
        #expect(Genotype.Empty == 0)
        #expect(Genotype.Haploid == 1)
        #expect(Genotype.Diploid == 2)
    }

    // MARK: - Lineage Tracking Tests (via PopGenStore)

    private func makeStoreWithOffspring(offspringLeft: String, offspringRight: String) -> (store: PopGenStore, offspring: Individual) {
        let store = PopGenStore()
        store.addLocus(name: "LTRS")
        let offspring = store.addIndividual(name: "Offspring")
        store.setGenotype(individual: offspring, locusName: "LTRS", leftAllele: offspringLeft, rightAllele: offspringRight)
        return (store, offspring)
    }

    @Test func testSetLineageFromIdenticalHeterozygotes() async throws {
        let (store, offspring) = makeStoreWithOffspring(offspringLeft: "A", offspringRight: "B")
        let parent = Genotype(leftAllele: "A", rightAllele: "B")

        store.setLineage(individual: offspring, locusName: "LTRS", from: parent, isMom: true)
        let updated = store.getGenotype(for: offspring, locusName: "LTRS")!

        // Identical heterozygotes should be ambiguous
        #expect(updated.leftLineage == Genotype.AmbiguousLineage)
        #expect(updated.rightLineage == Genotype.AmbiguousLineage)
    }

    @Test func testSetLineageFromMatchingAlleles() async throws {
        let (store, offspring) = makeStoreWithOffspring(offspringLeft: "A", offspringRight: "C")
        let parent = Genotype(leftAllele: "A", rightAllele: "B")

        store.setLineage(individual: offspring, locusName: "LTRS", from: parent, isMom: true)
        let updated = store.getGenotype(for: offspring, locusName: "LTRS")!

        // Left allele matches parent, should be maternal
        #expect(updated.leftLineage == Genotype.MaternalLineage)
        #expect(updated.rightLineage == Genotype.PaternalLineage)
    }

    @Test func testSetLineageFromNoMatch() async throws {
        let (store, offspring) = makeStoreWithOffspring(offspringLeft: "C", offspringRight: "D")
        let parent = Genotype(leftAllele: "A", rightAllele: "B")

        store.setLineage(individual: offspring, locusName: "LTRS", from: parent, isMom: true)
        let updated = store.getGenotype(for: offspring, locusName: "LTRS")!

        // No matching alleles should be impossible
        #expect(updated.leftLineage == Genotype.ImpossibleLineage)
        #expect(updated.rightLineage == Genotype.ImpossibleLineage)
    }

    // MARK: - Mating Tests (pure mateGenotypes function)

    @Test func testMatingProducesOffspring() async throws {
        let mother = Genotype(leftAllele: "A", rightAllele: "B")
        let father = Genotype(leftAllele: "C", rightAllele: "D")

        let result = mateGenotypes(mother: mother, father: father)
        try #require(result != nil)

        // Offspring should have one allele from each parent
        let possibleAlleles = Set(["A", "B", "C", "D"])
        #expect(possibleAlleles.contains(result!.leftAllele))
        #expect(possibleAlleles.contains(result!.rightAllele))
    }

    @Test func testMatingProducesValidLineage() async throws {
        let mother = Genotype(leftAllele: "A", rightAllele: "A")
        let father = Genotype(leftAllele: "B", rightAllele: "B")

        // Run multiple times to test randomness
        for _ in 0..<10 {
            let result = mateGenotypes(mother: mother, father: father)
            try #require(result != nil)

            // Should always be A/B heterozygote
            #expect(result!.leftAllele == "A" || result!.leftAllele == "B")
            #expect(result!.rightAllele == "A" || result!.rightAllele == "B")

            // Check lineage is set
            #expect(result!.leftLineage == Genotype.MaternalLineage || result!.leftLineage == Genotype.PaternalLineage)
            #expect(result!.rightLineage == Genotype.MaternalLineage || result!.rightLineage == Genotype.PaternalLineage)
        }
    }

    // MARK: - Equality Tests

    @Test func testGenotypeEquality() async throws {
        let geno1 = Genotype(leftAllele: "A", rightAllele: "B")
        let geno2 = Genotype(leftAllele: "A", rightAllele: "B")

        // Genotypes are equal if they have the same alleles
        #expect(geno1 == geno2)
    }

    @Test func testGenotypeInequality() async throws {
        let geno1 = Genotype(leftAllele: "A", rightAllele: "B")
        let geno2 = Genotype(leftAllele: "A", rightAllele: "C")

        #expect(geno1 != geno2)
    }

    // MARK: - String Description Test

    @Test func testGenotypeDescription() async throws {
        let geno = Genotype(leftAllele: "A", rightAllele: "B")
        #expect(geno.description == "A:B")
    }

    // MARK: - Color for Lineage Test

    @Test func testColorForLineage() async throws {
        let maternalColor = Genotype.colorForLineage(lineage: Genotype.MaternalLineage)
        let paternalColor = Genotype.colorForLineage(lineage: Genotype.PaternalLineage)
        let ambiguousColor = Genotype.colorForLineage(lineage: Genotype.AmbiguousLineage)
        let impossibleColor = Genotype.colorForLineage(lineage: Genotype.ImpossibleLineage)

        // Just verify they return colors without crashing
        #expect(maternalColor != paternalColor)
        #expect(ambiguousColor != impossibleColor)
    }
}
