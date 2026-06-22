//
//  MatrixTests.swift
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
//  Created by Rodney Dyer on 6/7/21.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Testing
@testable import Matrix

struct MatrixTests {
    
    @Test func testInit() {
        let M = Matrix(4, 4, 1.0)
        
        #expect(M.cols == 4)
        #expect(M.rows == 4)
        #expect(M[0,0] == 1.0)
        #expect(M.sum == 16.0)
        
        #expect(M.diagonal == Vector.zeros(4) + 1.0)
        #expect(M.diagonal.sum == 4.0)
    
        
        let rsum = M.rowSum
        #expect(rsum.sum == M.sum)
        #expect(rsum.count == 4)
        #expect(rsum[0] == 4.0)
        
        #expect(M.rowSum == M.colSum)
        #expect(M.rowMatrix == Matrix(4, 4, 4.0))
        
    }

    @Test func testInitSizeMismatchProducesConsistentEmpty() {
        // Regression: a vector whose length != r*c must yield a consistent
        // empty matrix, not full-sized name arrays backed by an empty buffer
        // (which would report 2x3 dimensions but crash on an in-bounds read).
        let M = Matrix(2, 3, Vector([1.0, 2.0]))
        #expect(M.rows == 0)
        #expect(M.cols == 0)
        #expect(M[0, 0].isNaN)   // out of bounds → nan, not a crash
    }

    @Test func testInitClosedRangeSingleElement() {
        // Regression: r*c == 1 must not divide by zero when spanning a range.
        let M = Matrix(1, 1, 5.0...10.0)
        #expect(M.rows == 1)
        #expect(M.cols == 1)
        #expect(M[0, 0] == 5.0)
    }

    @Test func testOutOfBoundsSubscript() {
        let M = Matrix(2, 2, 1.0)

        // Out-of-bounds reads return .nan (not a crash), including negatives.
        #expect(M[5, 5].isNaN)
        #expect(M[-1, 0].isNaN)
        #expect(M[0, -1].isNaN)

        // Out-of-bounds writes are silently ignored and leave the matrix intact.
        M[5, 5] = 99.0
        M[-1, 0] = 99.0
        #expect(M.sum == 4.0, "Out-of-bounds writes must not alter the matrix")
        #expect(M[0, 0] == 1.0)
    }

    @Test func testEquality() {
        
        let X = Matrix( 2, 2, 1...4 )
        let Y = Matrix( 2, 2, 2...5 )
        let Z = Matrix( 2, 3 )
        Z[0,0] = 1
        Z[0,1] = 2
        Z[1,0] = 3
        Z[1,1] = 4
        
        #expect(!(X == Y))
        #expect(!(X == Z))
        
        #expect(X == Z.submatrix([0,1], [0,1]))
    }
    
    @Test func testDesignMatrix() {
        
        let populations = ["RVA","RVA","RVA","Olympia","Olympia"]
        let X = Matrix.DesignMatrix(strata: populations )
        
        
        
        #expect(X.rows == 5)
        #expect(X.cols == 2)
        
        let H = Matrix(5,2)
        H[0,1] = 1.0
        H[1,1] = 1.0
        H[2,1] = 1.0
        H[3,0] = 1.0
        H[4,0] = 1.0
        
        #expect(X == H)
        
    }
    
    
    @Test func testIdempotentDesignMatrix() {
        
        let populations = ["RVA","RVA","RVA","Olympia","Olympia"]
        let X = Matrix.IdempotentHatMatrix(strata: populations )
         
        let H = Matrix(5,5,0.0)
        let c1 = 1.0 / 3.0
        let c2 = 1.0 / 2.0
        
        H[0,0] = c1
        H[0,1] = c1
        H[0,2] = c1
        H[1,0] = c1
        H[1,1] = c1
        H[1,2] = c1
        H[2,0] = c1
        H[2,1] = c1
        H[2,2] = c1
        
        H[3,3] = c2
        H[3,4] = c2
        H[4,3] = c2
        H[4,4] = c2
                
        #expect(H == X)
        
        
    }
    
    
    
    
    
    @Test func testConversion_DistanceCovarianceDistance() {
        
        var D = Matrix(3,3,0.0)
        D[0,1] = 2.0
        D[0,2] = 5.0
        D = D + D.transpose
        
        #expect(D[1,0] == D[0,1])
        #expect(D.diagonal.sum == 0.0)
        #expect(D[1,2] == 0.0)
        
        let C = D.asCovariance
        #expect(C.rows == 3)
        #expect(C.cols == C.rows)
        #expect(C[0,1] == C[1,0])
        #expect(C[2,1] == C[1,2])
        
        let D1 = C.asDistance
        #expect( (D - D1).sum < 0.00000000001) 
        
    }
    

    
    
    @Test func testMatrixRSourceConvertable() {
        
        var D = Matrix(3,3,0.0)
        D[0,1] = 2.0
        D[0,2] = 5.0
        D = D + D.transpose
        
        // as Matrix Output
        let ret1 = D.toR()
        #expect(!ret1.isEmpty)
        #expect(ret1 == "matrix( c(0.0,2.0,5.0,2.0,0.0,0.0,5.0,0.0,0.0), ncol=3, nrow=3, byrow=TRUE)")
        
        
        // as Tibble without Key
        D.colNames = ["First","Second","Third"]
        let ret2 = D.toR()
        #expect(!ret2.isEmpty)
        #expect(ret2.count == 93)
        
        D.rowNames  = ["Olympia","Ames","Richmond"]
        let ret3 = D.toR()
        #expect(ret3.count == 135)
    }
    
    
    
}
