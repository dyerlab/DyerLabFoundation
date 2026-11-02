//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AnalysisOptions.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// Settings shared by every analysis run.
public struct AnalysisOptions: Sendable, Equatable {

    /// Number of resampling iterations — permutations for a permutation test,
    /// subsamples for rarefaction. `0` skips a permutation test. Ignored by
    /// techniques whose `AnalysisType.usesIterations` is `false`.
    public var iterations: Int

    /// PRNG seed, so a run can be reproduced.
    public var seed: UInt64

    /// Creates run settings.
    ///
    /// - Parameters:
    ///   - iterations: Number of resampling iterations (default `999`).
    ///   - seed: PRNG seed (default `0`).
    /// - Precondition: `iterations >= 0`.
    public init(iterations: Int = 999, seed: UInt64 = 0) {
        precondition(iterations >= 0, "AnalysisOptions: iterations (\(iterations)) must be non-negative")
        self.iterations = iterations
        self.seed = seed
    }
}
