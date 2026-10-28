//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MatrixGroupsTests.swift
//  MatrixTests
//
//  Hand-computed fixtures for Matrix+Groups.swift and Matrix.asCovariance
//  (Gower's distance-to-covariance transform).
//
//  Created by Rodney Dyer on 2026.08.26.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import Matrix

struct MatrixGroupsTests {

    // 4 observations, 2 variables, 2 groups of 2.
    // Group A: (1,2), (3,4) -> mean (2,3)
    // Group B: (5,6), (9,10) -> mean (7,8)
    private let x = Matrix(4, 2, Vector([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 9.0, 10.0]))
    private let strata = ["A", "A", "B", "B"]

    @Test func groupMeansMatchesHandComputation() {
        let means = x.groupMeans(strata: strata)
        #expect(means.rows == 2)
        #expect(means.rowNames == ["A", "B"])
        #expect(isApprox(means[0, 0], 2.0, tolerance: 1e-12))
        #expect(isApprox(means[0, 1], 3.0, tolerance: 1e-12))
        #expect(isApprox(means[1, 0], 7.0, tolerance: 1e-12))
        #expect(isApprox(means[1, 1], 8.0, tolerance: 1e-12))
    }

    @Test func groupMeansBroadcastMatchesHandComputation() {
        let broadcast = x.groupMeansBroadcast(strata: strata)
        #expect(broadcast.rows == 4)
        for row in [0, 1] {
            #expect(isApprox(broadcast[row, 0], 2.0, tolerance: 1e-12))
            #expect(isApprox(broadcast[row, 1], 3.0, tolerance: 1e-12))
        }
        for row in [2, 3] {
            #expect(isApprox(broadcast[row, 0], 7.0, tolerance: 1e-12))
            #expect(isApprox(broadcast[row, 1], 8.0, tolerance: 1e-12))
        }
    }

    @Test func centroidVarianceMatchesHandComputation() {
        // Group A: var([1,3]) = 2, var([2,4]) = 2 -> sum 4
        // Group B: var([5,9]) = 8, var([6,10]) = 8 -> sum 16
        let variance = x.centroidVariance(strata: strata)
        #expect(isApprox(variance[0], 4.0, tolerance: 1e-12))
        #expect(isApprox(variance[1], 16.0, tolerance: 1e-12))
    }

    @Test func asCovarianceMatchesHandComputedGowerTransform() {
        // Hand-derived via Gower (1966): C = 0.5*(-D + rowMean + colMean - grandMean).
        let d = Matrix(3, 3, Vector([0.0, 4.0, 6.0, 4.0, 0.0, 8.0, 6.0, 8.0, 0.0]))
        let c = d.asCovariance

        #expect(isApprox(c[0, 0], 4.0 / 3.0, tolerance: 1e-9))
        #expect(isApprox(c[0, 1], -1.0 / 3.0, tolerance: 1e-9))
        #expect(isApprox(c[0, 2], -1.0, tolerance: 1e-9))
        #expect(isApprox(c[1, 1], 2.0, tolerance: 1e-9))
        #expect(isApprox(c[1, 2], -5.0 / 3.0, tolerance: 1e-9))
        #expect(isApprox(c[2, 2], 8.0 / 3.0, tolerance: 1e-9))
    }
}
