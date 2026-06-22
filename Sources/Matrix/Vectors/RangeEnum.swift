//
//  dyerlab.org                                          @dyerlab
//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
// 
//  DLabMatrix
//  RangeEnum.swift
//
//  Created by Rodney Dyer on 6/15/21.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.

import Foundation

/// Distribution types for random number generation.
///
/// Specifies the probability distribution to use when generating random vectors.
/// Used with `Vector.random(length:type:)`.
///
/// ## Available Distributions
///
/// - `.uniform_0_1`: Uniform distribution in the range [0, 1]
/// - `.uniform_neg1_1`: Uniform distribution in the range [-1, 1]
/// - `.normal_0_1`: Standard normal distribution (mean = 0, standard deviation = 1)
///
/// ## Example
/// ```swift
/// let uniform = Vector.random(length: 100, type: .uniform_0_1)
/// let normal = Vector.random(length: 100, type: .normal_0_1)
/// ```
public enum RangeEnum: Int, CaseIterable, Comparable {
    /// Uniform distribution in [0, 1]
    case uniform_0_1 = 1

    /// Uniform distribution in [-1, 1]
    case uniform_neg1_1 = 2

    /// Standard normal distribution (μ=0, σ=1)
    case normal_0_1 = 3

    public static func < (lhs: RangeEnum, rhs: RangeEnum) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
