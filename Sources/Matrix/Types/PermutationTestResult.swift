//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  PermutationTestResult.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 7/4/26.
//

import Foundation

/// The result of a randomization test for a general linear model, computed by
/// ``permutationTest(designMatrix:response:permutations:)``.
///
/// Rather than assuming an F-distribution, the response is repeatedly
/// shuffled against the fixed design matrix to build an empirical null
/// distribution of the among-group variance component (σ²_A, estimated as
/// `SSA / dfModel` — the same quantity as `LinearModelFit.msModel`) under the
/// null hypothesis. The observed value's rank within that null distribution
/// gives a distribution-free p-value.
public struct PermutationTestResult: Sendable {

    /// The general linear model fit to the unpermuted data.
    public let observed: LinearModelFit

    /// The among-group variance component (MSA) from each permutation.
    public let nullDistribution: Vector

    /// The number of permutations performed.
    public let permutations: Int

    /// The empirical one-sided p-value: the fraction of permuted MSA values
    /// at least as extreme as the observed one, with the standard add-one
    /// correction so a p-value of exactly zero is never reported.
    public var pValue: Double {
        let atLeastAsExtreme = nullDistribution.filter { $0 >= observed.msModel }.count
        return Double(atLeastAsExtreme + 1) / Double(permutations + 1)
    }

    public init(observed: LinearModelFit, nullDistribution: Vector, permutations: Int) {
        self.observed = observed
        self.nullDistribution = nullDistribution
        self.permutations = permutations
    }
}
