//
//  tSNEAffinity.swift
//  MatrixStuff
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
//  Created by Rodney Dyer on 2/3/26.
//

import Foundation

/// Find optimal sigma (bandwidth) for a single point using binary search
///
/// - Parameters:
///   - squaredDistances: Squared Euclidean distances from point i to all other points
///   - targetPerplexity: Desired perplexity value (typically 5-50)
///   - tolerance: Convergence tolerance for perplexity difference
///   - maxIterations: Maximum number of binary search iterations
/// - Returns: SigmaSearchResult containing optimal beta and probability distribution
public func findOptimalTSNESigma( squaredDistances: Vector, targetPerplexity: Double, tolerance: Double = 1e-5, maxIterations: Int = 50 ) -> SigmaSearchResult {
    
    let n = squaredDistances.count
    guard n > 0 else {
        return SigmaSearchResult(beta: 1.0, probabilities: [], perplexity: 0, iterations: 0)
    }
    
    // Initialize binary search bounds for beta (precision)
    var betaMin: Double = -.infinity
    var betaMax: Double = .infinity
    var beta: Double = 1.0  // Initial guess
    
    var probabilities = [Double](repeating: 0.0, count: n)
    var currentPerplexity: Double = 0
    var iteration = 0
    
    for iter in 0..<maxIterations {
        iteration = iter + 1
        
        // Compute probabilities with current beta
        // P_{j|i} = exp(-beta * ||x_i - x_j||^2) / sum_k(...)
        var expDistances = [Double](repeating: 0.0, count: n)
        var sumExp: Double = 0.0
        
        // Compute exponentials with numerical stability
        var maxValue: Double = -.infinity
        for k in 0..<n {
            let value = -squaredDistances[k] * beta
            maxValue = max(maxValue, value)
        }
        
        // Use log-sum-exp trick for numerical stability
        for k in 0..<n {
            let value = -squaredDistances[k] * beta - maxValue
            expDistances[k] = exp(value)
            sumExp += expDistances[k]
        }
        
        // Compute probabilities
        var entropy: Double = 0.0
        if sumExp > 1e-300 {  // Check for underflow
            for k in 0..<n {
                probabilities[k] = expDistances[k] / sumExp
                
                // Compute Shannon entropy: H(P_i) = -sum(p * log2(p))
                if probabilities[k] > 1e-12 {
                    entropy -= probabilities[k] * log2(probabilities[k])
                }
            }
        } else {
            // Beta too large, all probabilities → 0
            probabilities = [Double](repeating: 0.0, count: n)
            entropy = 0
        }
        
        // Compute perplexity from entropy: Perplexity = 2^H
        currentPerplexity = pow(2.0, entropy)
        
        // Check convergence
        let perplexityDiff = currentPerplexity - targetPerplexity
        
        if abs(perplexityDiff) < tolerance {
            break
        }
        
        // Update binary search bounds
        if perplexityDiff > 0 {
            // Current perplexity too high → need higher beta (lower sigma)
            betaMin = beta
            if betaMax.isInfinite {
                beta = beta * 2.0
            } else {
                beta = (beta + betaMax) / 2.0
            }
        } else {
            // Current perplexity too low → need lower beta (higher sigma)
            betaMax = beta
            if betaMin.isInfinite {
                beta = beta / 2.0
            } else {
                beta = (beta + betaMin) / 2.0
            }
        }
    }
    
    return SigmaSearchResult(
        beta: beta,
        probabilities: probabilities,
        perplexity: currentPerplexity,
        iterations: iteration
    )
}


