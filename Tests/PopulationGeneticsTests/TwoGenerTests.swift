//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  TwoGenerTests.swift
//  PopulationGeneticsTests
//
//  Distances are checked against the closed forms in Smouse et al. (2001),
//  eqs. 5–6, for a mother A1A3 and an ambiguous A1A3 offspring.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Testing
import Matrix
import PresentationZen
@testable import PopulationGenetics

struct TwoGenerTests {

    /// One locus, alleles 1–4. Each family is a mother genotype and its
    /// offspring genotypes; `nil` mother makes a motherless family.
    private func dataset(_ families: [(mother: (UInt8, UInt8)?, offspring: [(UInt8, UInt8)])])
        -> (GenotypeMatrix, ParentageDesign) {
        var codebook = AlleleCodebook()
        for allele in ["A1", "A2", "A3", "A4"] { codebook.register(allele) }
        var individuals: [Individual] = []
        var left: [UInt8] = []
        var right: [UInt8] = []
        var design: [MaternalFamily] = []
        for (f, family) in families.enumerated() {
            var motherOrdinal: Int?
            if let mother = family.mother {
                individuals.append(Individual(name: "Mom\(f)"))
                motherOrdinal = individuals.count - 1
                left.append(mother.0); right.append(mother.1)
            }
            var children: [Int] = []
            for (n, child) in family.offspring.enumerated() {
                individuals.append(Individual(name: "Off\(f)_\(n)"))
                children.append(individuals.count - 1)
                left.append(child.0); right.append(child.1)
            }
            design.append(MaternalFamily(id: "F\(f)", mother: motherOrdinal, offspring: children))
        }
        let column = MultiallelicColumn(codebook: codebook, left: left, right: right)
        return (GenotypeMatrix(individuals: individuals, loci: [Locus(name: "L1")], columns: [column]),
                ParentageDesign(families: design))
    }

    /// Mother A1A3 with an ambiguous A1A3 offspring (gamete 0), a resolved A2
    /// (1) and a resolved A1 (2); mother A4A4 with resolved A3 (3), A1 (4), A4 (5).
    private func paperExample() -> (GenotypeMatrix, ParentageDesign) {
        dataset([(mother: (1, 3), offspring: [(1, 3), (2, 3), (1, 1)]),
                 (mother: (4, 4), offspring: [(3, 4), (1, 4), (4, 4)])])
    }

    // MARK: - Smouse et al. (2001) scoring

    @Test func ambiguousDistancesMatchThePaper() throws {
        let (matrix, design) = paperExample()
        let analysis = try #require(TwoGenerAnalysis(matrix: matrix, design: design,
                                                     frequencyMethod: .paternalAverage))
        // Paternal average: A1 = 1 + 1 + ½, A2 = 1, A3 = 1 + ½, A4 = 1, over 6 gametes.
        let q = analysis.pollenPool[0]
        #expect(abs(q[1] - 2.5 / 6) < 1e-12)
        #expect(abs(q[3] - 1.5 / 6) < 1e-12)

        let a13 = q[1] / (q[1] + q[3])
        let a31 = 1 - a13
        let d = analysis.squaredDistances
        #expect(abs(d[0][1] - (1 - a13 * a31)) < 1e-12)   // eq. 6b: A1/3 vs A2
        #expect(abs(d[0][3] - a13 * a13) < 1e-12)          // eq. 6a: A1/3 vs A3
        #expect(abs(d[0][2] - a31 * a31) < 1e-12)          // eq. 5:  A1/3 vs A1
        #expect(d[1][2] == 1)                              // distinct resolved alleles
        #expect(d[2][4] == 0)                              // same resolved allele
    }

    @Test func emFrequenciesAreAFixedPointOfThePosterior() throws {
        let (matrix, design) = paperExample()
        let em = try #require(TwoGenerAnalysis(matrix: matrix, design: design))
        let average = try #require(TwoGenerAnalysis(matrix: matrix, design: design,
                                                    frequencyMethod: .paternalAverage))
        let q = em.pollenPool[0]
        // Resolved: A1 ×2, A2, A3, A4; one ambiguous A1/A3 gamete split by its posterior.
        let w = q[1] / (q[1] + q[3])
        #expect(abs(q[1] - (2 + w) / 6) < 1e-10)
        #expect(abs(q[3] - (1 + (1 - w)) / 6) < 1e-10)
        #expect(abs(q.reduce(0, +) - 1) < 1e-12)
        #expect(abs(q[1] - average.pollenPool[0][1]) > 1e-3)
        #expect(em.notes.contains { $0.logType == .assumption && $0.message.contains("expectation–maximization") })
    }

    // MARK: - Missing, impossible and motherless

    @Test func missingGenotypesAreImputedFromThePollenPool() throws {
        let (matrix, design) = dataset([(mother: (1, 1), offspring: [(1, 2), (1, 3), (0, 0)]),
                                        (mother: (2, 2), offspring: [(2, 1), (2, 2)])])
        let analysis = try #require(TwoGenerAnalysis(matrix: matrix, design: design))
        // Recovered: A2, A3, A1, A2 → q = (¼, ½, ¼) over A1–A3.
        let q = analysis.pollenPool[0]
        #expect(q[1] == 0.25 && q[2] == 0.5 && q[3] == 0.25)
        // Imputed gamete (2) against resolved A2 (0): ½[(q1)² + (1 − q2)² + (q3)²].
        #expect(abs(analysis.squaredDistances[2][0] - 0.1875) < 1e-12)
        #expect(analysis.notes.contains { $0.logType == .assumption && $0.message.contains("imputed") })
        #expect(analysis.offspring.count == 5)
    }

    @Test func impossibleOffspringAreDroppedAndLogged() throws {
        let (matrix, design) = dataset([(mother: (1, 1), offspring: [(1, 2), (2, 3), (1, 3)]),
                                        (mother: (2, 2), offspring: [(2, 1), (2, 4)])])
        let analysis = try #require(TwoGenerAnalysis(matrix: matrix, design: design))
        #expect(analysis.offspring.count == 4)
        #expect(!analysis.offspring.contains(2))           // Off0_1 (A2A3) shares nothing with A1A1
        let warning = try #require(analysis.notes.first { $0.logType == .warning })
        #expect(warning.message.contains("Off0_1") && warning.message.contains("Mom0"))
        let report = try #require(analysis.perform(options: AnalysisOptions(iterations: 0))).report
        #expect(report.methods.contains("1 offspring that shared no allele"))
        #expect(report.logEntries.allSatisfy { $0.analysisTag == .twoGenerPhiFT })
        #expect(report.logEntries.contains { $0.logType == .warning && $0.message == warning.message })
    }

    @Test func aLocusSubsetIgnoresImpossibilitiesElsewhere() throws {
        let (first, design) = dataset([(mother: (1, 1), offspring: [(1, 2), (2, 3), (1, 3)]),
                                       (mother: (2, 2), offspring: [(2, 1), (2, 4)])])
        let (second, _) = dataset([(mother: (1, 1), offspring: [(1, 2), (1, 3), (1, 3)]),
                                   (mother: (2, 2), offspring: [(2, 1), (2, 4)])])
        let matrix = GenotypeMatrix(individuals: first.individuals,
                                    loci: [Locus(name: "L1"), Locus(name: "L2")],
                                    columns: [first.columns[0], second.columns[0]])
        let all = try #require(TwoGenerAnalysis(matrix: matrix, design: design))
        #expect(all.offspring.count == 4)

        let subset = try #require(TwoGenerAnalysis(matrix: matrix, design: design, loci: [1]))
        let alone = try #require(TwoGenerAnalysis(matrix: second, design: design))
        #expect(subset.offspring.count == 5)
        #expect(subset.pollenPool[0].isEmpty && subset.pollenPool[1] == alone.pollenPool[0])
        #expect(subset.squaredDistances == alone.squaredDistances)
        #expect(!subset.notes.contains { $0.logType == .warning })
    }

    @Test func motherlessFamiliesAreSkippedAndLogged() throws {
        let (matrix, design) = dataset([(mother: (1, 1), offspring: [(1, 2), (1, 3)]),
                                        (mother: (2, 2), offspring: [(2, 1), (2, 4)]),
                                        (mother: nil, offspring: [(1, 2), (3, 4)])])
        let analysis = try #require(TwoGenerAnalysis(matrix: matrix, design: design))
        #expect(Set(analysis.partition) == [0, 1])
        #expect(analysis.notes.contains { $0.logType == .warning && $0.message.contains("F2 has no mother") })
    }

    // MARK: - Φ_FT

    @Test func phiFTIsAMOVAOfTheGameteDistances() throws {
        let (matrix, design) = paperExample()
        let analysis = try #require(TwoGenerAnalysis(matrix: matrix, design: design))
        let outcome = try #require(analysis.run(options: AnalysisOptions(iterations: 99, seed: 4)))
        let direct = try #require(VarianceDecompositionAnalysis(squaredDistances: analysis.squaredDistances,
                                                                partition: analysis.partition,
                                                                tag: .twoGenerPhiFT)?
            .run(options: AnalysisOptions(iterations: 99, seed: 4)))
        #expect(outcome.analysisType == .twoGener)
        #expect(outcome.phiFT == direct.statistic)
        #expect(outcome.distribution == direct.distribution)
        #expect(outcome.gameteCount == 6 && outcome.motherCount == 2)
    }

    @Test func oneSirePerMotherGivesCompleteStructure() throws {
        let (matrix, design) = dataset([(mother: (1, 1), offspring: [(1, 2), (1, 2), (1, 2)]),
                                        (mother: (1, 1), offspring: [(1, 3), (1, 3), (1, 3)]),
                                        (mother: (1, 1), offspring: [(1, 4), (1, 4), (1, 4)])])
        let outcome = try #require(TwoGenerAnalysis(matrix: matrix, design: design)?
            .run(options: AnalysisOptions(iterations: 0)))
        #expect(abs(outcome.phiFT - 1) < 1e-12)
    }

    @Test func tooFewMothersGiveNil() {
        let (matrix, design) = dataset([(mother: (1, 1), offspring: [(1, 2), (1, 3)])])
        #expect(TwoGenerAnalysis(matrix: matrix, design: design) == nil)
    }
}
