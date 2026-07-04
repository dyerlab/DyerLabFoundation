//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Created by Rodney Dyer on 7/4/26.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import Matrix

struct LinearModelFitTests {

    @Test func simpleRegressionMatchesHandComputedValues() throws {
        // x = 1...5, y = [2, 4, 5, 4, 5] — a textbook example with slope = 0.6,
        // intercept = 2.2, R² = 0.6.
        let x: Vector = [1, 2, 3, 4, 5]
        let y: Vector = [2, 4, 5, 4, 5]
        let X = Matrix(5, 2, x.flatMap { [1.0, $0] })

        let fit = try #require(linearModelFit(designMatrix: X, response: y))

        #expect(abs(fit.coefficients[0] - 2.2) < 1e-9)  // intercept
        #expect(abs(fit.coefficients[1] - 0.6) < 1e-9)  // slope
        #expect(abs(fit.r2 - 0.6) < 1e-9)
        #expect(abs(fit.ssTotal - 6.0) < 1e-9)
        #expect(abs(fit.ssModel - 3.6) < 1e-9)
        #expect(abs(fit.ssResidual - 2.4) < 1e-9)
        #expect(fit.dfModel == 1)
        #expect(fit.dfResidual == 3)
        #expect(fit.dfTotal == 4)
        #expect(abs(fit.msModel - 3.6) < 1e-9)
        #expect(abs(fit.msResidual - 0.8) < 1e-9)
        #expect(abs(fit.fStatistic - 4.5) < 1e-9)
    }

    @Test func oneWayAnovaFromDesignMatrixMatchesHandComputedValues() throws {
        // Two groups: RVA = [1, 2, 3], Olympia = [10, 12].
        let populations = ["RVA", "RVA", "RVA", "Olympia", "Olympia"]
        let y: Vector = [1, 2, 3, 10, 12]
        let X = Matrix.DesignMatrix(strata: populations)

        let fit = try #require(linearModelFit(designMatrix: X, response: y))

        // DesignMatrix sorts group labels alphabetically: Olympia, then RVA.
        #expect(abs(fit.coefficients[0] - 11.0) < 1e-9)  // Olympia mean
        #expect(abs(fit.coefficients[1] - 2.0) < 1e-9)   // RVA mean
        #expect(abs(fit.ssResidual - 4.0) < 1e-9)
        #expect(abs(fit.ssTotal - 101.2) < 1e-9)
        #expect(abs(fit.ssModel - 97.2) < 1e-9)
        #expect(fit.dfModel == 1)
        #expect(fit.dfResidual == 3)
        #expect(fit.dfTotal == 4)
        #expect(abs(fit.fStatistic - 72.9) < 1e-6)
    }

    @Test func tooFewObservationsReturnsNil() {
        // One observation can't estimate two parameters: X'X is rank-1 (singular).
        let X = Matrix(1, 2, [1.0, 5.0])
        #expect(linearModelFit(designMatrix: X, response: [3.0]) == nil)
    }

    @Test func exactFitHasZeroResidualDegreesOfFreedom() throws {
        // Exactly two points determine a line exactly: N == p is allowed, the
        // fit is well-defined, but there's no residual variance to speak of
        // (dividing by zero residual df yields inf/nan, not a crash).
        let X = Matrix(2, 2, [1.0, 1.0, 1.0, 2.0])
        let fit = try #require(linearModelFit(designMatrix: X, response: [3.0, 5.0]))

        #expect(abs(fit.coefficients[0] - 1.0) < 1e-9)  // intercept
        #expect(abs(fit.coefficients[1] - 2.0) < 1e-9)  // slope
        #expect(abs(fit.ssResidual) < 1e-9)
        #expect(fit.dfResidual == 0)
        #expect(!fit.msResidual.isFinite || fit.msResidual == 0)
    }

    @Test func singularDesignMatrixReturnsNil() {
        // Two identical predictor columns make X'X singular.
        let X = Matrix(3, 2, [1.0, 1.0, 2.0, 2.0, 3.0, 3.0])
        #expect(linearModelFit(designMatrix: X, response: [1.0, 2.0, 3.0]) == nil)
    }

    @Test func mismatchedRowCountReturnsNil() {
        let X = Matrix(3, 2, [1.0, 1.0, 1.0, 2.0, 1.0, 3.0])
        #expect(linearModelFit(designMatrix: X, response: [1.0, 2.0]) == nil)
    }
}
