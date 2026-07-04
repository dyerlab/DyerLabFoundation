//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  HypergeometricScenariosTests.swift
//

import Foundation
import Testing
@testable import Matrix
@testable import PresentationZen

@Suite("hypergeometricScenarios")
struct HypergeometricScenariosTests {

    @Test("scenario rows are labeled atLeast, exact, lessThan in that order")
    func scenarioLabels() {
        let table = hypergeometricScenarios(populationSize: 40, successesInPopulation: 4, draws: 7, observedSuccesses: 1)
        #expect(table.rowCount == 3)
        #expect(table.stringColumn("scenario") == ["atLeast", "exact", "lessThan"])
    }

    @Test("x/y roles are pre-bound for plotting")
    func roles() {
        let table = hypergeometricScenarios(populationSize: 40, successesInPopulation: 4, draws: 7, observedSuccesses: 1)
        #expect(table.column(for: .x) == "scenario")
        #expect(table.column(for: .y) == "probability")
    }

    @Test("atLeast and lessThan are complementary and exact matches the underlying probability")
    func probabilitiesAreConsistent() {
        let populationSize = 40, successesInPopulation = 4, draws = 7, observedSuccesses = 1
        let table = hypergeometricScenarios(populationSize: populationSize, successesInPopulation: successesInPopulation, draws: draws, observedSuccesses: observedSuccesses)
        let probabilities = table.numericColumn("probability").compactMap { $0 }
        #expect(probabilities.count == 3)

        let atLeast = probabilities[0], exact = probabilities[1], lessThan = probabilities[2]
        #expect(abs(atLeast + lessThan - 1.0) < 1e-9)
        #expect(exact == hypergeometricProbability(populationSize: populationSize, successesInPopulation: successesInPopulation, draws: draws, observedSuccesses: observedSuccesses))
        #expect(exact <= atLeast)
    }

    @Test("target beyond what the draw can produce is certain failure")
    func unreachableTargetIsCertainFailure() {
        let table = hypergeometricScenarios(populationSize: 40, successesInPopulation: 4, draws: 7, observedSuccesses: 5)
        let probabilities = table.numericColumn("probability").compactMap { $0 }
        #expect(probabilities[0] == 0.0)  // atLeast
        #expect(probabilities[1] == 0.0)  // exact
        #expect(abs(probabilities[2] - 1.0) < 1e-9)  // lessThan
    }

    @Test("invalid population returns NaN for every scenario")
    func invalidPopulationReturnsNaN() {
        let table = hypergeometricScenarios(populationSize: 10, successesInPopulation: 11, draws: 5, observedSuccesses: 1)
        let probabilities = table.numericColumn("probability").compactMap { $0 }
        #expect(probabilities.allSatisfy { $0.isNaN })
    }
}
