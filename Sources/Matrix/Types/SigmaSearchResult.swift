//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  SigmaSearchResult.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 2/3/26.
//

import Foundation

/// Result of a binary search for the optimal sigma in
/// ``findOptimalTSNESigma(squaredDistances:targetPerplexity:tolerance:maxIterations:)``.
///
/// Stores the precision parameter (beta = 1 / 2σ²), the resulting conditional
/// probability distribution, the achieved perplexity, and the number of search
/// iterations required to converge.
public struct SigmaSearchResult {

    /// Precision parameter: β = (2σ²)⁻¹.
    let beta: Double

    /// Conditional probability distribution P(j|i) over the input neighbours.
    let probabilities: [Double]

    /// Perplexity achieved at the converged sigma.
    let perplexity: Double

    /// Number of binary-search iterations required.
    let iterations: Int
}
