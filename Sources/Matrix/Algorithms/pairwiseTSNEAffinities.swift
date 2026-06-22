//
//  pairwiseTSNEAffinities.swift
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

/// Compute pairwise affinity matrix for all points
///
/// - Parameters:
///   - dataMatrix: N × D matrix of data points (flattened row-major)
///   - dimensions: Number of dimensions (D)
///   - targetPerplexity: Desired perplexity value
/// - Returns: Symmetric N × N affinity matrix (flattened row-major)
public func pairwiseTSNEAffinities( dataMatrix: Matrix, targetPerplexity: Double) -> Matrix {
        
        let n = dataMatrix.rows
        let d = dataMatrix.cols
        
        guard n > 0 && d > 0 else {
            return Matrix(0, 0, 0.0)
        }
        
        // Initialize conditional probability matrix P (N × N)
        let conditionalP = Matrix(n, n, 0.0)

        // Compute affinities for each point
        for i in 0..<n {
            // Extract point i as a vector
            let pointI = dataMatrix.getRow(r: i)
            
            // Compute squared distances to all other points
            var squaredDistances: [Double] = []
            var indices: [Int] = []
            
            for j in 0..<n {
                if i != j {
                    let pointJ = dataMatrix.getRow(r: j)
                    let sqDist = squaredEuclideanDistance(pointI, pointJ)
                    squaredDistances.append(sqDist)
                    indices.append(j)
                }
            }
            
            // Find optimal sigma for this point
            let result = findOptimalTSNESigma(
                squaredDistances: squaredDistances,
                targetPerplexity: targetPerplexity
            )
            
            // Store conditional probabilities P_{j|i}
            for (idx, j) in indices.enumerated() {
                conditionalP[i, j] = result.probabilities[idx]
            }
        }
        
        // Symmetrize: p_ij = (p_{j|i} + p_{i|j}) / (2N)
        let symmetricP = Matrix(n, n, 0.0)
        let normalizationFactor = 1.0 / (2.0 * Double(n))
        
        for i in 0..<n {
            for j in 0..<n {
                let pji = conditionalP[j, i]
                let pij = conditionalP[i, j]
                symmetricP[i, j] = (pij + pji) * normalizationFactor
            }
        }

        return symmetricP
    }
