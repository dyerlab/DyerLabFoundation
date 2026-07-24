//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  OutcrossingTests.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 7/23/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

import XCTest
@testable import PopulationGenetics

final class OutcrossingTests: XCTestCase {

    func testOutcrossingRun() {
        // Create a dummy matrix and design
        let loci = [
            Locus(name: "L1"),
            Locus(name: "L2")
        ]

        let individuals = [
            Individual(name: "F1_O1"),
            Individual(name: "F1_O2"),
            Individual(name: "F2_O1")
        ]

        var cb1 = AlleleCodebook()
        cb1.register("100")
        cb1.register("102")

        var cb2 = AlleleCodebook()
        cb2.register("200")
        cb2.register("202")

        let col1 = MultiallelicColumn(codebook: cb1, left: [1, 1, 2], right: [1, 2, 2])
        let col2 = MultiallelicColumn(codebook: cb2, left: [1, 2, 1], right: [1, 2, 2])

        let matrix = GenotypeMatrix(individuals: individuals, loci: loci, columns: [col1, col2])

        let fam1 = MaternalFamily(id: "F1", mother: nil, offspring: [0, 1])
        let fam2 = MaternalFamily(id: "F2", mother: nil, offspring: [2])
        let design = ParentageDesign(families: [fam1, fam2])

        var params = Outcrossing.Parameters()
        params.numSteps = 100
        params.burnIn = 10
        params.thinning = 1

        let result = matrix.runOutcrossing(design: design, parameters: params)

        XCTAssertEqual(result.samples.count, 90)
        XCTAssert(result.meanT >= 0.0 && result.meanT <= 1.0)
        XCTAssert(result.meanF >= 0.0 && result.meanF <= 1.0)
    }

    // MARK: - Offspring probability math

    /// Mother heterozygous for a null allele (0/ms). An apparent homozygote
    /// matching `ms` is reachable two ways (mom transmits the invisible null
    /// and pollen supplies `ms`, or mom transmits `ms` and pollen supplies
    /// `ms` or the population's own null); an apparent homozygote for any
    /// *other* allele is reachable only the first way. These must not collapse
    /// to the same formula.
    func testOutcrossingProbabilityMomHetWithNullAllele() {
        let frequencies = [0.2, 0.3, 0.5] // [null, allele 1, allele 2]

        let matching = Outcrossing.probabilityOfOffspringGivenOutcrossing(
            (2, 2), givenMother: (0, 2), frequencies: frequencies, hasNullModel: true
        )
        XCTAssertEqual(matching, 0.5 * (0.5 / 0.8) + 0.5 * (0.5 + 0.2), accuracy: 1e-12)

        let nonMatching = Outcrossing.probabilityOfOffspringGivenOutcrossing(
            (1, 1), givenMother: (0, 2), frequencies: frequencies, hasNullModel: true
        )
        XCTAssertEqual(nonMatching, 0.5 * (0.3 / 0.8), accuracy: 1e-12)
    }

    /// Mother heterozygous for two real (non-null) alleles, at a locus that
    /// still models a null allele elsewhere in the population. An apparent
    /// homozygote matching one of her alleles must include the null-allele
    /// correction (pollen could have supplied the invisible null instead) —
    /// unlike the standard (no null model) case.
    func testOutcrossingProbabilityMomHetWithoutNullAlleleAtNullModeledLocus() {
        let frequencies = [0.2, 0.3, 0.5] // [null, allele 1, allele 2]

        let withNullModel = Outcrossing.probabilityOfOffspringGivenOutcrossing(
            (1, 1), givenMother: (1, 2), frequencies: frequencies, hasNullModel: true
        )
        XCTAssertEqual(withNullModel, 0.5 * (0.3 + 0.2), accuracy: 1e-12)

        let standardModel = Outcrossing.probabilityOfOffspringGivenOutcrossing(
            (1, 1), givenMother: (1, 2), frequencies: frequencies, hasNullModel: false
        )
        XCTAssertEqual(standardModel, 0.5 * 0.3, accuracy: 1e-12)
    }

    // MARK: - Multilocus mixing

    /// The mixture between selfing and outcrossing must happen once per
    /// offspring, over the *product* of single-locus probabilities across
    /// every locus — not independently per locus. A shared mating event
    /// produces one offspring; per-locus mixing would let each locus behave
    /// as though selfed or outcrossed independently, which is a different
    /// (wrong) model and destroys the cross-locus correlation multilocus
    /// outcrossing-rate estimators rely on.
    func testProgenyLogLikelihoodMixesAtTheMultilocusLevel() {
        var cbA = AlleleCodebook()
        cbA.register("100")
        cbA.register("102")

        var cbB = AlleleCodebook()
        cbB.register("200")
        cbB.register("202")

        // Mom homozygous 100/100 at locus A, 202/202 at locus B; offspring matches at both.
        let colA = MultiallelicColumn(codebook: cbA, left: [1, 1], right: [1, 1])
        let colB = MultiallelicColumn(codebook: cbB, left: [2, 2], right: [2, 2])

        let matrix = GenotypeMatrix(
            individuals: [Individual(name: "Mom"), Individual(name: "Offspring")],
            loci: [Locus(name: "A"), Locus(name: "B")],
            columns: [colA, colB]
        )
        let design = ParentageDesign(families: [MaternalFamily(id: "F1", mother: 0, offspring: [1])])
        let sampler = Outcrossing.Sampler(matrix: matrix, design: design)

        var state = sampler.currentState
        state.t = 0.5
        state.maternalGenotypes = [[(1, 1), (2, 2)]]
        state.alleleFrequencies = [[0.0, 0.4, 0.6], [0.0, 0.3, 0.7]]

        let logLikelihood = sampler.progenyLogLikelihood(familyIndex: 0, state: state)

        // Correct (mixture-of-products): (1-t)*(1.0*1.0) + t*(0.4*0.7) = 0.64.
        // The bug this guards against (product-of-mixtures) would instead give
        // (0.5*1.0 + 0.5*0.4) * (0.5*1.0 + 0.5*0.7) = 0.595.
        XCTAssertEqual(exp(logLikelihood), 0.64, accuracy: 1e-9)
    }

    // MARK: - Convergence sanity

    /// Builds a matrix of families all sharing a homozygous mother
    /// genotype at a single 3-allele locus, with offspring genotypes
    /// deterministically consistent with either an all-selfing or an
    /// all-outcrossing generating process.
    ///
    /// - Parameter allSelfed: If `true`, every offspring is homozygous
    ///   identical to its mother (the only genotype selfing can produce). If
    ///   `false`, every offspring carries an allele its mother cannot
    ///   transmit (impossible under selfing, so only outcrossing explains it).
    private func makeMatingSystemMatrix(allSelfed: Bool) -> (GenotypeMatrix, ParentageDesign) {
        var codebook = AlleleCodebook()
        codebook.register("A")
        codebook.register("B")
        codebook.register("C")

        var individuals: [Individual] = []
        var left: [UInt8] = []
        var right: [UInt8] = []
        var families: [MaternalFamily] = []

        // Nine mothers, homozygous 1/1, 2/2, or 3/3 in turn, so the family
        // data alone carries roughly equal allele frequencies.
        let momAlleles: [UInt8] = [1, 1, 1, 2, 2, 2, 3, 3, 3]
        let otherAlleles: [UInt8: [UInt8]] = [1: [2, 3], 2: [1, 3], 3: [1, 2]]

        for (familyIndex, momAllele) in momAlleles.enumerated() {
            individuals.append(Individual(name: "Mom\(familyIndex)"))
            let momOrdinal = individuals.count - 1
            left.append(momAllele)
            right.append(momAllele)

            var offspringOrdinals: [Int] = []
            for n in 0..<6 {
                individuals.append(Individual(name: "Off\(familyIndex)_\(n)"))
                offspringOrdinals.append(individuals.count - 1)
                left.append(momAllele) // Every offspring always carries the mother's transmitted allele.
                right.append(allSelfed ? momAllele : otherAlleles[momAllele]![n % 2])
            }
            families.append(MaternalFamily(id: "F\(familyIndex)", mother: momOrdinal, offspring: offspringOrdinals))
        }

        let column = MultiallelicColumn(codebook: codebook, left: left, right: right)
        let matrix = GenotypeMatrix(individuals: individuals, loci: [Locus(name: "L1")], columns: [column])
        return (matrix, ParentageDesign(families: families))
    }

    func testMostlySelfingDataRecoversLowOutcrossingRate() {
        let (matrix, design) = makeMatingSystemMatrix(allSelfed: true)

        var params = Outcrossing.Parameters()
        params.numSteps = 4000
        params.burnIn = 1000
        params.thinning = 5
        params.seed = 42

        let result = matrix.runOutcrossing(design: design, parameters: params)
        XCTAssertLessThan(result.meanT, 0.35)
    }

    func testMostlyOutcrossingDataRecoversHighOutcrossingRate() {
        let (matrix, design) = makeMatingSystemMatrix(allSelfed: false)

        var params = Outcrossing.Parameters()
        params.numSteps = 4000
        params.burnIn = 1000
        params.thinning = 5
        params.seed = 42

        let result = matrix.runOutcrossing(design: design, parameters: params)
        XCTAssertGreaterThan(result.meanT, 0.65)
    }

    // MARK: - Single-locus outcrossing rate (t_s)

    /// For a matrix with exactly one locus, restricting the sampler to that
    /// locus (`t_s`) versus running it over every locus (`t_m`) is the same
    /// computation — `activeLoci` is `[0]` either way — so with the same
    /// seed the chains must produce bit-identical results. This pins down
    /// that the `loci:` restriction doesn't silently change behavior when
    /// there's nothing to restrict.
    func testSingleLocusMatchesMultilocusForOneLocusMatrix() {
        let (matrix, design) = makeMatingSystemMatrix(allSelfed: false)

        var params = Outcrossing.Parameters()
        params.numSteps = 500
        params.burnIn = 100
        params.thinning = 5
        params.seed = 7

        let multilocus = matrix.runOutcrossing(design: design, parameters: params)
        let singleLocus = matrix.runOutcrossing(atLocus: 0, design: design, parameters: params)

        XCTAssertEqual(multilocus.meanT, singleLocus.meanT, accuracy: 1e-12)
        XCTAssertEqual(multilocus.meanF, singleLocus.meanF, accuracy: 1e-12)
    }

    /// `runSingleLocusOutcrossing` estimates `t` independently at every
    /// locus, so it must return one result per locus, each restricted to
    /// only that locus's information.
    func testRunSingleLocusOutcrossingReturnsOneResultPerLocus() {
        var cbA = AlleleCodebook()
        cbA.register("100")
        cbA.register("102")

        var cbB = AlleleCodebook()
        cbB.register("200")
        cbB.register("202")

        let colA = MultiallelicColumn(codebook: cbA, left: [1, 1], right: [1, 1])
        let colB = MultiallelicColumn(codebook: cbB, left: [2, 2], right: [2, 2])

        let matrix = GenotypeMatrix(
            individuals: [Individual(name: "Mom"), Individual(name: "Offspring")],
            loci: [Locus(name: "A"), Locus(name: "B")],
            columns: [colA, colB]
        )
        let design = ParentageDesign(families: [MaternalFamily(id: "F1", mother: 0, offspring: [1])])

        var params = Outcrossing.Parameters()
        params.numSteps = 200
        params.burnIn = 50
        params.thinning = 5
        params.seed = 3

        let results = matrix.runSingleLocusOutcrossing(design: design, parameters: params)

        XCTAssertEqual(results.count, 2)
        for result in results {
            XCTAssert(result.meanT >= 0.0 && result.meanT <= 1.0)
        }
    }
}
