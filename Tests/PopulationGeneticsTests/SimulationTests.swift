//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//
//  Created by Rodney Dyer on 4/23/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

import Testing
import Matrix
@testable import PopulationGenetics

// MARK: - Simulation Tests

struct SimulationTests {

    // MARK: - Shared fixtures

    private static let biallelic3Loci: [String: [String: Double]] = [
        "L01": ["01": 0.6, "02": 0.4],
        "L02": ["01": 0.3, "02": 0.7],
        "L03": ["01": 0.5, "02": 0.5]
    ]

    private static let singleLocus: [String: [String: Double]] = [
        "L01": ["01": 0.8, "02": 0.2]
    ]

    // MARK: - makePopulation

    @Test func makePopulationProducesCorrectCount() {
        let (_, individuals) = makePopulation(
            locusFrequencies: Self.biallelic3Loci,
            populationName: "Pop01",
            size: 50
        )
        #expect(individuals.count == 50)
    }

    @Test func makePopulationAllIndividualsHaveAllLoci() {
        let (store, individuals) = makePopulation(
            locusFrequencies: Self.biallelic3Loci,
            populationName: "Pop01",
            size: 20
        )
        for individual in individuals {
            let lociNames = store.getLocusNames(for: individual)
            #expect(lociNames.count == 3)
            #expect(lociNames.sorted() == ["L01", "L02", "L03"])
        }
    }

    @Test func makePopulationGenotypesAreDiploid() {
        let (store, individuals) = makePopulation(
            locusFrequencies: Self.biallelic3Loci,
            populationName: "Pop01",
            size: 20
        )
        for individual in individuals {
            let genotypes = store.getGenotypes(for: individual)
            for geno in genotypes {
                #expect(geno.ploidy == Genotype.Diploid)
            }
        }
    }

    @Test func makePopulationRegistersStratum() {
        let (store, _) = makePopulation(
            locusFrequencies: Self.biallelic3Loci,
            populationName: "Pop01",
            size: 10
        )
        let stratum = store.getStratum(named: "Pop01", within: "Population")
        #expect(stratum != nil)
        #expect(store.individualCount(for: stratum!) == 10)
    }

    @Test func makePopulationAllelesAreValid() {
        let (store, individuals) = makePopulation(
            locusFrequencies: Self.singleLocus,
            populationName: "Pop01",
            size: 30
        )
        let validAlleles: Set<String> = ["01", "02"]
        for individual in individuals {
            if let geno = store.getGenotype(for: individual, locusName: "L01") {
                #expect(validAlleles.contains(geno.leftAllele))
                #expect(validAlleles.contains(geno.rightAllele))
                // Lexicographic sort invariant
                #expect(geno.leftAllele <= geno.rightAllele)
            }
        }
    }

    // MARK: - randomMate

    @Test func randomMateProducesCorrectOffspringCount() {
        let (store, parents) = makePopulation(
            locusFrequencies: Self.biallelic3Loci,
            populationName: "Pop01",
            size: 20
        )
        let offspring = randomMate(parents: parents, offspringCount: 30, store: store)
        #expect(offspring.count == 30)
    }

    @Test func randomMateOffspringHaveAllLoci() {
        let (store, parents) = makePopulation(
            locusFrequencies: Self.biallelic3Loci,
            populationName: "Pop01",
            size: 20
        )
        let offspring = randomMate(parents: parents, offspringCount: 10, store: store)
        for child in offspring {
            let lociNames = store.getLocusNames(for: child)
            #expect(lociNames.sorted() == ["L01", "L02", "L03"])
        }
    }

    @Test func randomMateOffspringAllelesFromParents() {
        let (store, parents) = makePopulation(
            locusFrequencies: Self.singleLocus,
            populationName: "Pop01",
            size: 20
        )
        let validAlleles: Set<String> = ["01", "02"]
        let offspring = randomMate(parents: parents, offspringCount: 10, store: store)
        for child in offspring {
            if let geno = store.getGenotype(for: child, locusName: "L01") {
                #expect(validAlleles.contains(geno.leftAllele))
                #expect(validAlleles.contains(geno.rightAllele))
            }
        }
    }

    @Test func randomMateEmptyParentsReturnsEmpty() {
        let store = PopGenStore()
        let offspring = randomMate(parents: [], offspringCount: 10, store: store)
        #expect(offspring.isEmpty)
    }

    // MARK: - applyMigration

    private func makeSimpleMatrix(k: Int, migrationRate: Double) -> Matrix {
        let names = (1...k).map { "Pop\($0)" }
        let mat = Matrix(k, k, names, names)
        for i in 0..<k {
            for j in 0..<k {
                if i == j {
                    mat[i, j] = 1.0 - migrationRate
                } else {
                    mat[i, j] = migrationRate / Double(k - 1)
                }
            }
        }
        return mat
    }

    @Test func applyMigrationConservesTotalIndividuals() {
        let (_, indA) = makePopulation(
            locusFrequencies: Self.singleLocus,
            populationName: "Pop1",
            size: 100
        )
        let (_, indB) = makePopulation(
            locusFrequencies: Self.singleLocus,
            populationName: "Pop2",
            size: 100
        )
        let populations = ["Pop1": indA, "Pop2": indB]
        let mat = makeSimpleMatrix(k: 2, migrationRate: 0.1)

        let result = applyMigration(populations: populations, matrix: mat)
        let totalBefore = populations.values.map(\.count).reduce(0, +)
        let totalAfter  = result.values.map(\.count).reduce(0, +)
        #expect(totalAfter == totalBefore)
    }

    @Test func applyMigrationClampsRoundingOverflowInsteadOfDroppingADestination() {
        // Row A: stay 0%, 50% to B, 50% to C. Over 3 individuals, each 0.5
        // fraction independently rounds up to 2 (`Int(1.5.rounded())`), so the
        // naive per-column counts sum to 4 — one more than the 3 available.
        // Before the fix, the destination processed second (C, since B is
        // column index 1 and C is column index 2) would have its count
        // silently dropped to 0 entirely rather than clamped to what's left.
        let names = ["A", "B", "C"]
        let mat = Matrix(3, 3, names, names)
        mat[0, 0] = 0.0; mat[0, 1] = 0.5; mat[0, 2] = 0.5
        mat[1, 0] = 0.0; mat[1, 1] = 1.0; mat[1, 2] = 0.0
        mat[2, 0] = 0.0; mat[2, 1] = 0.0; mat[2, 2] = 1.0

        let indA = (0..<3).map { Individual(name: "A-\($0)") }
        let populations = ["A": indA, "B": [Individual](), "C": [Individual]()]

        let result = applyMigration(populations: populations, matrix: mat)

        #expect(result["A"]?.count == 0, "all of A's individuals should have emigrated (row sums to 0% stay)")
        #expect((result["B"]?.count ?? 0) + (result["C"]?.count ?? 0) == 3,
                "every emigrant must land somewhere, none silently dropped")
        #expect((result["C"]?.count ?? 0) > 0,
                "C must receive its clamped share rather than being zeroed out by the earlier column's rounding overflow")
    }

    @Test func applyMigrationZeroRateChangesNothing() {
        let (_, indA) = makePopulation(
            locusFrequencies: Self.singleLocus,
            populationName: "Pop1",
            size: 50
        )
        let (_, indB) = makePopulation(
            locusFrequencies: Self.singleLocus,
            populationName: "Pop2",
            size: 50
        )
        let populations = ["Pop1": indA, "Pop2": indB]
        let mat = makeSimpleMatrix(k: 2, migrationRate: 0.0)

        let result = applyMigration(populations: populations, matrix: mat)
        #expect(result["Pop1"]?.count == 50)
        #expect(result["Pop2"]?.count == 50)
    }

    @Test func applyMigrationMovesIndividuals() {
        let (_, indA) = makePopulation(
            locusFrequencies: Self.singleLocus,
            populationName: "Pop1",
            size: 100
        )
        let (_, indB) = makePopulation(
            locusFrequencies: Self.singleLocus,
            populationName: "Pop2",
            size: 100
        )
        let populations = ["Pop1": indA, "Pop2": indB]
        let mat = makeSimpleMatrix(k: 2, migrationRate: 0.1)

        let result = applyMigration(populations: populations, matrix: mat)
        // With 10% migration each way, both pops should remain near 100
        let count1 = result["Pop1"]?.count ?? 0
        let count2 = result["Pop2"]?.count ?? 0
        #expect(count1 > 0)
        #expect(count2 > 0)
        #expect(count1 + count2 == 200)
    }

    // MARK: - exportGenotypesCSV

    @Test func exportCSVHasCorrectHeader() {
        let (store, individuals) = makePopulation(
            locusFrequencies: Self.biallelic3Loci,
            populationName: "Pop01",
            size: 5
        )
        let csv = exportGenotypesCSV(
            individuals: individuals,
            locusNames: ["L01", "L02", "L03"],
            store: store
        )
        let header = csv.split(separator: "\n").first.map(String.init) ?? ""
        #expect(header == "Population,Individual,L01,L02,L03")
    }

    @Test func exportCSVRowCountMatchesIndividualCount() {
        let (store, individuals) = makePopulation(
            locusFrequencies: Self.biallelic3Loci,
            populationName: "Pop01",
            size: 10
        )
        let csv = exportGenotypesCSV(
            individuals: individuals,
            locusNames: ["L01", "L02", "L03"],
            store: store
        )
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines.count == 11) // 1 header + 10 data rows
    }

    @Test func exportCSVGenotypeCellFormat() {
        let (store, individuals) = makePopulation(
            locusFrequencies: Self.singleLocus,
            populationName: "Pop01",
            size: 5
        )
        let csv = exportGenotypesCSV(
            individuals: individuals,
            locusNames: ["L01"],
            store: store
        )
        let dataLines = csv.split(separator: "\n").dropFirst()
        for line in dataLines {
            let cols = line.split(separator: ",", omittingEmptySubsequences: false)
            #expect(cols.count == 3)
            let genoCell = String(cols[2])
            #expect(genoCell.contains(":"))
        }
    }

    @Test func exportCSVPopulationsOverloadGroupsByKey() {
        let (_, indA) = makePopulation(
            locusFrequencies: Self.singleLocus,
            populationName: "Pop1",
            size: 3
        )
        let (store, indB) = makePopulation(
            locusFrequencies: Self.singleLocus,
            populationName: "Pop2",
            size: 3
        )
        // Merge both populations into one store for the export
        // (In practice the engine uses a single store; here we just test the overload)
        let csv = exportGenotypesCSV(
            populations: ["Pop1": indA, "Pop2": indB],
            locusNames: ["L01"],
            store: store
        )
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: true)
        // header + 6 data rows
        #expect(lines.count == 7)
    }
}
