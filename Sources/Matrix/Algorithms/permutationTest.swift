//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  permutationTest.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 7/4/26.
//

import Foundation

/// Tests a general linear model's significance by randomization rather than
/// an assumed F-distribution, using the system random number generator.
///
/// - Parameters:
///   - X: The N×p design matrix.
///   - y: The response vector of length N.
///   - permutations: The number of random shuffles of `y` to perform.
/// - Returns: A ``PermutationTestResult``, or `nil` if the model can't be
///   fit (see `linearModelFit(designMatrix:response:)`) or `permutations` is
///   not positive.
public func permutationTest(designMatrix X: Matrix, response y: Vector,
                             permutations: Int = 999) -> PermutationTestResult? {
    var generator = SystemRandomNumberGenerator()
    return permutationTest(designMatrix: X, response: y, permutations: permutations, using: &generator)
}

/// Tests a general linear model's significance by randomization, using a
/// caller-supplied generator.
///
/// Shuffles `y` against the fixed design matrix `X` `permutations` times,
/// refitting each time to build an empirical null distribution of the
/// among-group variance component (MSA) under the null hypothesis. Supplying
/// a deterministic generator (e.g. a seeded one) makes the result
/// reproducible, which is useful for tests.
///
/// Two identities make this cheap: the total sum of squares is invariant
/// under permuting `y` (the same multiset of values, just reordered), so
/// only the residual sum of squares needs computing per permutation — the
/// model sum of squares follows by subtraction. And since only `y` changes
/// across permutations, the `(X'X)⁻¹X'` coefficient projector is computed
/// once outside the loop rather than re-running `GeneralizedInverse`'s LU
/// factorization on every iteration.
///
/// - Parameters:
///   - X: The N×p design matrix.
///   - y: The response vector of length N.
///   - permutations: The number of random shuffles of `y` to perform.
///   - generator: The random number generator to draw shuffles from.
/// - Returns: A ``PermutationTestResult``, or `nil` if the model can't be
///   fit (see `linearModelFit(designMatrix:response:)`) or `permutations` is
///   not positive.
public func permutationTest<G: RandomNumberGenerator>(designMatrix X: Matrix, response y: Vector,
                                                        permutations: Int = 999,
                                                        using generator: inout G) -> PermutationTestResult? {
    guard let observed = linearModelFit(designMatrix: X, response: y), permutations > 0 else { return nil }

    let projector = GeneralizedInverse(X.transpose .* X) .* X.transpose
    let dfModel = Double(observed.dfModel)

    var nullDistribution = Vector()
    nullDistribution.reserveCapacity(permutations)

    for _ in 0 ..< permutations {
        let permutedY = y.shuffled(using: &generator)
        let coefficients = (projector .* Matrix(permutedY.count, 1, permutedY)).getCol(c: 0)
        let fitted = (X .* Matrix(X.cols, 1, coefficients)).getCol(c: 0)
        let ssResidual = zip(permutedY, fitted).map { ($0 - $1) * ($0 - $1) }.sum
        let ssModel = observed.ssTotal - ssResidual
        nullDistribution.append(ssModel / dfModel)
    }

    return PermutationTestResult(observed: observed, nullDistribution: nullDistribution, permutations: permutations)
}
