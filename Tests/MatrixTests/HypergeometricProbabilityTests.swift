//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  HypergeometricProbabilityTests.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 7/4/26.
//

import Testing
@testable import Matrix

struct HypergeometricProbabilityTests {

    @Test
    func matchesKnownCardDrawProbability() {
        // 40-card deck, 4 copies of a card, drawing a 7-card opening hand.
        // P(X=1) = C(4,1)·C(36,6) / C(40,7) = 4·1947792 / 18643560 ≈ 0.41790.
        let probability = hypergeometricProbability(
            populationSize: 40,
            successesInPopulation: 4,
            draws: 7,
            observedSuccesses: 1
        )
        #expect(abs(probability - 0.41790) < 1e-4)
    }

    @Test
    func probabilitiesAcrossAllOutcomesSumToOne() {
        let populationSize = 40
        let successesInPopulation = 4
        let draws = 7
        let total = (0...draws).reduce(0.0) { sum, observedSuccesses in
            sum + hypergeometricProbability(
                populationSize: populationSize,
                successesInPopulation: successesInPopulation,
                draws: draws,
                observedSuccesses: observedSuccesses
            )
        }
        #expect(abs(total - 1.0) < 1e-9)
    }

    @Test
    func drawingMoreSuccessesThanExistIsImpossible() {
        let probability = hypergeometricProbability(
            populationSize: 40,
            successesInPopulation: 4,
            draws: 7,
            observedSuccesses: 5
        )
        #expect(probability == 0.0)
    }

    @Test
    func drawingEverySuccessWhenAllAreDrawnIsCertain() {
        let probability = hypergeometricProbability(
            populationSize: 10,
            successesInPopulation: 3,
            draws: 10,
            observedSuccesses: 3
        )
        #expect(abs(probability - 1.0) < 1e-9)
    }

    @Test
    func invalidPopulationReturnsNaN() {
        #expect(hypergeometricProbability(populationSize: 10, successesInPopulation: 11, draws: 5, observedSuccesses: 1).isNaN)
        #expect(hypergeometricProbability(populationSize: 10, successesInPopulation: 3, draws: 11, observedSuccesses: 1).isNaN)
        #expect(hypergeometricProbability(populationSize: -1, successesInPopulation: 0, draws: 0, observedSuccesses: 0).isNaN)
    }
}
