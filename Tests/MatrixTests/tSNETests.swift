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
//  File.swift
//  MatrixStuff
//
//  Created by Rodney Dyer on 2/3/26.
//


import Testing
import SceneKit
import CoreGraphics

@testable import Matrix

struct tSNETests {
    
    
    
    
    @Test
    func exampleTSNEWithMatrix() {
        
        // Create a sample data matrix: 5 points in 2D space
        // Points 0-2 form one cluster, points 3-4 form another cluster
        let dataValues: Vector = [
            0.0, 0.0,      // Point 0
            1.0, 0.0,      // Point 1
            0.0, 1.0,      // Point 2
            5.0, 5.0,      // Point 3
            5.1, 5.0       // Point 4
        ]
        
        let dataMatrix = Matrix(5, 2, dataValues)
        let targetPerplexity = 3.0

        // Compute t-SNE affinities
        let affinities = pairwiseTSNEAffinities(
            dataMatrix: dataMatrix,
            targetPerplexity: targetPerplexity
        )

        // The symmetric affinity matrix P sums to 1 with a zero diagonal.
        #expect( abs(affinities.sum - 1.0) < 1e-9 )
        #expect( affinities.trace == 0.0 )

        // Row sums should be similar across rows.
        let rowSumVar = affinities.rowSum.variance
        #expect( rowSumVar < 0.001 )
    }
    
    
    @Test
    func testWithLargerDataset() {
        
        // Create a dataset with two well-separated clusters
        // Cluster 1: 15 points around (0, 0)
        // Cluster 2: 15 points around (10, 10)
        var dataValues: Vector = []
        var rng = SeededGenerator(seed: 2024)   // deterministic clusters

        // Cluster 1 around (0, 0)
        for _ in 0..<15 {
            dataValues.append(Double.random(in: -1.0...1.0, using: &rng))
            dataValues.append(Double.random(in: -1.0...1.0, using: &rng))
        }

        // Cluster 2 around (10, 10)
        for _ in 0..<15 {
            dataValues.append(10.0 + Double.random(in: -1.0...1.0, using: &rng))
            dataValues.append(10.0 + Double.random(in: -1.0...1.0, using: &rng))
        }

        let dataMatrix = Matrix(30, 2, dataValues)
        let targetPerplexity = 10.0

        let affinities = pairwiseTSNEAffinities(
            dataMatrix: dataMatrix,
            targetPerplexity: targetPerplexity
        )

        #expect( affinities.rows == 30 && affinities.cols == 30 )
        #expect( abs(affinities.sum - 1.0) < 1e-9 )
        #expect( affinities.trace == 0.0 )

        // Cluster structure: a within-cluster pair (0,1) should have a much higher
        // affinity than a cross-cluster pair (0,15). This is the property the test
        // previously only printed but never asserted.
        #expect( affinities[0, 1] > affinities[0, 15] )
    }

    @Test
    func emptyDataReturnsEmptyMatrix() {
        // No points (or no dimensions) → an empty affinity matrix, not a crash.
        let empty = pairwiseTSNEAffinities(dataMatrix: Matrix(0, 0, 0.0), targetPerplexity: 5.0)
        #expect(empty.rows == 0)
        #expect(empty.cols == 0)
    }

    @Test
    func findOptimalSigmaEmptyReturnsDefault() {
        // With no distances the binary search can't run; it returns the default
        // result (no probabilities, zero iterations) rather than looping or crashing.
        let result = findOptimalTSNESigma(squaredDistances: [], targetPerplexity: 10.0)
        #expect(result.probabilities.isEmpty)
        #expect(result.iterations == 0)
        #expect(result.perplexity == 0)
        #expect(result.beta == 1.0)
    }

    @Test
    func findOptimalSigmaProducesValidDistribution() {
        // Four neighbors at increasing distances; the binary search should yield a
        // valid probability distribution and approach the requested perplexity.
        let result = findOptimalTSNESigma(squaredDistances: [1.0, 4.0, 9.0, 16.0], targetPerplexity: 2.0)

        #expect(result.probabilities.count == 4)
        #expect(result.probabilities.allSatisfy { $0 >= 0.0 })
        #expect(abs(result.probabilities.sum - 1.0) < 1e-9, "Conditional probabilities sum to 1")
        #expect(result.beta > 0.0)
        #expect(result.iterations >= 1)
        #expect(abs(result.perplexity - 2.0) < 0.5, "Achieved perplexity approaches the target")
    }

    @Test
    func findOptimalSigmaSingleNeighbor() {
        // With a single neighbor all probability mass falls on it.
        let result = findOptimalTSNESigma(squaredDistances: [5.0], targetPerplexity: 1.0)
        #expect(result.probabilities == [1.0])
    }
}
