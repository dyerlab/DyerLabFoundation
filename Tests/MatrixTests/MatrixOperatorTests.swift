//
//  MatrixOperatorTests.swift
//  Tests macOS
//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Created by Claude Code on 1/11/26.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Testing
@testable import Matrix

struct MatrixOperatorTests {

    @Test func testMatrixScalarAddition() {
        let M = Matrix(2, 2, Vector([1.0, 2.0, 3.0, 4.0]))
        let result = M + 10.0

        #expect(result[0,0] == 11.0)
        #expect(result[0,1] == 12.0)
        #expect(result[1,0] == 13.0)
        #expect(result[1,1] == 14.0)
    }

    @Test func testMatrixScalarSubtraction() {
        let M = Matrix(2, 2, Vector([10.0, 8.0, 6.0, 4.0]))
        let result = M - 3.0

        #expect(result[0,0] == 7.0)
        #expect(result[0,1] == 5.0)
        #expect(result[1,0] == 3.0)
        #expect(result[1,1] == 1.0)
    }

    @Test func testMatrixScalarMultiplication() {
        let M = Matrix(2, 2, Vector([1.0, 2.0, 3.0, 4.0]))
        let result = M * 2.0

        #expect(result[0,0] == 2.0)
        #expect(result[0,1] == 4.0)
        #expect(result[1,0] == 6.0)
        #expect(result[1,1] == 8.0)
    }

    @Test func testMatrixScalarDivision() {
        let M = Matrix(2, 2, Vector([10.0, 20.0, 30.0, 40.0]))
        let result = M / 10.0

        #expect(result[0,0] == 1.0)
        #expect(result[0,1] == 2.0)
        #expect(result[1,0] == 3.0)
        #expect(result[1,1] == 4.0)
    }

    @Test func testMatrixElementwiseAddition() {
        let M1 = Matrix(2, 2, Vector([1.0, 2.0, 3.0, 4.0]))
        let M2 = Matrix(2, 2, Vector([5.0, 6.0, 7.0, 8.0]))
        let result = M1 + M2

        #expect(result[0,0] == 6.0)
        #expect(result[0,1] == 8.0)
        #expect(result[1,0] == 10.0)
        #expect(result[1,1] == 12.0)
    }

    @Test func testMatrixElementwiseSubtraction() {
        let M1 = Matrix(2, 2, Vector([10.0, 9.0, 8.0, 7.0]))
        let M2 = Matrix(2, 2, Vector([1.0, 2.0, 3.0, 4.0]))
        let result = M1 - M2

        #expect(result[0,0] == 9.0)
        #expect(result[0,1] == 7.0)
        #expect(result[1,0] == 5.0)
        #expect(result[1,1] == 3.0)
    }

    @Test func testMatrixElementwiseMultiplication() {
        let M1 = Matrix(2, 2, Vector([2.0, 3.0, 4.0, 5.0]))
        let M2 = Matrix(2, 2, Vector([1.0, 2.0, 3.0, 4.0]))
        let result = M1 * M2

        #expect(result[0,0] == 2.0)
        #expect(result[0,1] == 6.0)
        #expect(result[1,0] == 12.0)
        #expect(result[1,1] == 20.0)
    }

    @Test func testMatrixElementwiseDivision() {
        let M1 = Matrix(2, 2, Vector([10.0, 20.0, 30.0, 40.0]))
        let M2 = Matrix(2, 2, Vector([2.0, 4.0, 5.0, 8.0]))
        let result = M1 / M2

        #expect(result[0,0] == 5.0)
        #expect(result[0,1] == 5.0)
        #expect(result[1,0] == 6.0)
        #expect(result[1,1] == 5.0)
    }

    @Test func testMatrixMultiplication() {
        // Test simple 2x2 matrix multiplication
        let M1 = Matrix(2, 2, Vector([1.0, 2.0, 3.0, 4.0]))
        let M2 = Matrix(2, 2, Vector([5.0, 6.0, 7.0, 8.0]))
        let result = M1 .* M2

        // Expected: [1*5+2*7, 1*6+2*8]  = [19, 22]
        //           [3*5+4*7, 3*6+4*8]  = [43, 50]
        #expect(result[0,0] == 19.0)
        #expect(result[0,1] == 22.0)
        #expect(result[1,0] == 43.0)
        #expect(result[1,1] == 50.0)
    }

    @Test func testMatrixMultiplicationNonSquare() {
        // Test 2x3 * 3x2 = 2x2
        let M1 = Matrix(2, 3, Vector([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]))
        let M2 = Matrix(3, 2, Vector([7.0, 8.0, 9.0, 10.0, 11.0, 12.0]))
        let result = M1 .* M2

        #expect(result.rows == 2)
        #expect(result.cols == 2)

        // Expected: [1*7+2*9+3*11, 1*8+2*10+3*12]  = [58, 64]
        //           [4*7+5*9+6*11, 4*8+5*10+6*12]  = [139, 154]
        #expect(result[0,0] == 58.0)
        #expect(result[0,1] == 64.0)
        #expect(result[1,0] == 139.0)
        #expect(result[1,1] == 154.0)
    }

    @Test func testMatrixVectorMultiplication() {
        // Note: The M .* v operator requires rows(M) == length(v), not cols(M) == length(v)
        // This is a non-standard implementation
        let M = Matrix(3, 2, Vector([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]))
        let v = Vector([1.0, 2.0, 3.0])
        let result = M .* v

        #expect(result.count == 3)
        // Row 0: [1, 2] .* [1, 2, 3] → dot product of first 2 elements = 1*1 + 2*2 = 5
        // Row 1: [3, 4] .* [1, 2, 3] → dot product of first 2 elements = 3*1 + 4*2 = 11
        // Row 2: [5, 6] .* [1, 2, 3] → dot product of first 2 elements = 5*1 + 6*2 = 17
        #expect(result[0] == 5.0)
        #expect(result[1] == 11.0)
        #expect(result[2] == 17.0)
    }

    @Test func testMatrixTranspose() {
        let M = Matrix(2, 3, Vector([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]))
        let MT = M.transpose

        #expect(MT.rows == 3)
        #expect(MT.cols == 2)
        #expect(MT[0,0] == 1.0)
        #expect(MT[0,1] == 4.0)
        #expect(MT[1,0] == 2.0)
        #expect(MT[1,1] == 5.0)
        #expect(MT[2,0] == 3.0)
        #expect(MT[2,1] == 6.0)
    }

    @Test func testIdentityMatrixMultiplication() {
        let M = Matrix(3, 3, Vector([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0]))
        let I = Matrix(3, 3, 0.0)
        I.diagonal = Vector([1.0, 1.0, 1.0])

        let result = M .* I

        // M * I should equal M
        #expect((M - result).sum < 0.0000001)
    }
}
