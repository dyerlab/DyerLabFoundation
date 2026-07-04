//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Created by Rodney Dyer on 7/4/26.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import Matrix

struct PermutationTestTests {

    @Test func sameSeedProducesIdenticalNullDistribution() throws {
        let populations = ["A", "A", "A", "B", "B", "B"]
        let y: Vector = [1, 2, 3, 10, 11, 12]
        let X = Matrix.DesignMatrix(strata: populations)

        var rngOne = SeededGenerator(seed: 42)
        var rngTwo = SeededGenerator(seed: 42)

        let resultOne = try #require(permutationTest(designMatrix: X, response: y, permutations: 50, using: &rngOne))
        let resultTwo = try #require(permutationTest(designMatrix: X, response: y, permutations: 50, using: &rngTwo))

        #expect(resultOne.nullDistribution == resultTwo.nullDistribution)
    }

    @Test func strongGroupEffectYieldsSmallPValue() throws {
        // Two well-separated groups: the observed MSA should dwarf almost
        // every permuted MSA.
        let populations = ["A", "A", "A", "A", "A", "B", "B", "B", "B", "B"]
        let y: Vector = [1, 2, 1.5, 2.5, 1.8, 20, 21, 19.5, 20.5, 20.2]
        let X = Matrix.DesignMatrix(strata: populations)

        var rng = SeededGenerator(seed: 7)
        let result = try #require(permutationTest(designMatrix: X, response: y, permutations: 999, using: &rng))

        #expect(result.nullDistribution.count == 999)
        #expect(result.pValue < 0.05)
        let exceededCount = result.nullDistribution.filter { $0 >= result.observed.msModel }.count
        #expect(exceededCount < 10)
    }

    @Test func noRealEffectYieldsLargePValue() throws {
        // Group labels are unrelated to the response — the observed MSA
        // should look like a typical draw from its own null distribution.
        let populations = ["A", "A", "A", "A", "A", "B", "B", "B", "B", "B"]
        let y: Vector = [5, 12, 3, 9, 7, 6, 4, 11, 8, 10]
        let X = Matrix.DesignMatrix(strata: populations)

        var rng = SeededGenerator(seed: 99)
        let result = try #require(permutationTest(designMatrix: X, response: y, permutations: 999, using: &rng))

        #expect(result.pValue > 0.05)
    }

    @Test func nonPositivePermutationsReturnsNil() {
        let X = Matrix.DesignMatrix(strata: ["A", "A", "B", "B"])
        var rng = SeededGenerator(seed: 1)
        #expect(permutationTest(designMatrix: X, response: [1, 2, 3, 4], permutations: 0, using: &rng) == nil)
    }

    @Test func unfittableModelReturnsNil() {
        // One observation can't estimate two parameters.
        let X = Matrix(1, 2, [1.0, 5.0])
        var rng = SeededGenerator(seed: 1)
        #expect(permutationTest(designMatrix: X, response: [3.0], permutations: 10, using: &rng) == nil)
    }
}
