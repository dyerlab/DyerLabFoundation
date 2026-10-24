//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RRandomTests.swift
//  MatrixTests
//
//  Verifies RMersenneTwister reproduces R's set.seed()/runif()/sample() output
//  bit-for-bit. Reference values captured from R 4.x with the default RNGkind
//  ("Mersenne-Twister" / "Inversion" / "Rejection"):
//
//    set.seed(42);       runif(5)
//    set.seed(42);       sample(10)
//    set.seed(42);       sample(20, 5)
//    set.seed(1);        sample(7)
//    set.seed(123);      runif(3)
//    set.seed(20260902); sample(12)
//
//  Created by Rodney Dyer on 2026.09.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Testing
@testable import Matrix

struct RRandomTests {

    @Test func unifRandMatchesRSeed42() {
        var rng = RMersenneTwister(seed: 42)
        let expected = [0.91480604349635541, 0.93707541329786181, 0.28613953478634357,
                        0.83044762606732547, 0.64174551889300346]
        for e in expected {
            #expect(abs(rng.unifRand() - e) < 1e-15)
        }
    }

    @Test func unifRandMatchesRSeed123() {
        var rng = RMersenneTwister(seed: 123)
        let expected = [0.28757752012461424, 0.78830513544380665, 0.40897692181169987]
        for e in expected {
            #expect(abs(rng.unifRand() - e) < 1e-15)
        }
    }

    @Test func permutationMatchesRSample() {
        var a = RMersenneTwister(seed: 42)
        #expect(a.permutation(10) == [1, 5, 10, 8, 2, 4, 6, 9, 7, 3])

        var b = RMersenneTwister(seed: 1)
        #expect(b.permutation(7) == [1, 4, 7, 2, 5, 3, 6])

        var c = RMersenneTwister(seed: 20260902)
        #expect(c.permutation(12) == [12, 10, 9, 11, 5, 6, 8, 3, 1, 4, 7, 2])
    }

    @Test func sampleWithoutReplacementMatchesR() {
        var rng = RMersenneTwister(seed: 42)
        // R: set.seed(42); sample(20, 5)  ->  17 5 1 10 4   (1-based)
        let drawn = rng.sampleIndicesNoReplacement(n: 20, size: 5).map { $0 + 1 }
        #expect(drawn == [17, 5, 1, 10, 4])
    }

    @Test func sampleWithReplacementMatchesR() {
        var a = RMersenneTwister(seed: 7)
        #expect(a.sample(Array(1...10), size: 10, replace: true) == [10, 3, 7, 2, 10, 6, 8, 8, 3, 8])

        var b = RMersenneTwister(seed: 7)
        #expect(b.sample(Array(1...5), size: 8, replace: true) == [2, 3, 4, 2, 2, 3, 3, 2])

        var c = RMersenneTwister(seed: 99)
        #expect(c.sample(Array(1...6), size: 6, replace: true) == [1, 4, 6, 6, 5, 3])
    }
}
