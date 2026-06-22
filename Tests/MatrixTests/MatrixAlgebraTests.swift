//
//  MatrixAlgebraTests.swift
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

import Foundation
import Testing
@testable import Matrix

struct MatrixAlgebraTests {

    @Test func testGeneralizedInverse() {
        // Test with a simple invertible 2x2 matrix
        let M = Matrix(2, 2, Vector([4.0, 7.0, 2.0, 6.0]))
        let Minv = GeneralizedInverse(M)

        #expect(Minv.rows == 2)
        #expect(Minv.cols == 2)

        // M * M^-1 should equal identity matrix
        let I = M .* Minv

        // Check diagonal is approximately 1.0
        let tolerance = 0.0001
        #expect(abs(I[0,0] - 1.0) < tolerance)
        #expect(abs(I[1,1] - 1.0) < tolerance)

        // Check off-diagonal is approximately 0.0
        #expect(abs(I[0,1]) < tolerance)
        #expect(abs(I[1,0]) < tolerance)
    }

    @Test func testGeneralizedInverse3x3() {
        // Test with a 3x3 matrix
        let M = Matrix(3, 3, Vector([1.0, 2.0, 3.0, 0.0, 1.0, 4.0, 5.0, 6.0, 0.0]))
        let Minv = GeneralizedInverse(M)

        let I = M .* Minv

        let tolerance = 0.0001
        #expect(abs(I[0,0] - 1.0) < tolerance)
        #expect(abs(I[1,1] - 1.0) < tolerance)
        #expect(abs(I[2,2] - 1.0) < tolerance)
    }

    @Test func testGeneralizedInverseNonSquare() {
        // Non-square matrices should return empty matrix
        let M = Matrix(2, 3, 1.0)
        let Minv = GeneralizedInverse(M)

        #expect(Minv.rows == 0)
        #expect(Minv.cols == 0)
    }

    @Test func testGeneralizedInverseSingularReturnsEmpty() {
        // A singular (rank-deficient) matrix has no inverse: LU factorization
        // hits a zero pivot, so the contract is to return an empty 0×0 matrix
        // rather than NaN-filled garbage. Row 2 = 2 × Row 1 ⇒ singular.
        let M = Matrix(2, 2, Vector([1.0, 2.0, 2.0, 4.0]))
        let Minv = GeneralizedInverse(M)

        #expect(Minv.rows == 0)
        #expect(Minv.cols == 0)
    }

    @Test func testDominantEigenvectorDegenerateReturnsNil() {
        // Non-square input is rejected up front.
        #expect(DominantEigenvector(A: Matrix(2, 3, 1.0)) == nil)

        // The zero matrix has only the zero eigenvalue, so the iteration cannot
        // normalize (norm is 0) and must return nil rather than NaN.
        #expect(DominantEigenvector(A: Matrix(2, 2, 0.0)) == nil)
    }

    @Test func testSingularValueDecomposition() {
        // Test SVD on a simple matrix
        let A = Matrix(3, 2, Vector([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]))

        guard let svd = SingularValueDecomposition(A) else {
            Issue.record("SVD should not return nil for valid matrix")
            return
        }

        #expect(svd.U.rows == 3)
        #expect(svd.d.count == 2)
        #expect(svd.V.rows == 2)

        // Singular values should be positive and in descending order
        #expect(svd.d[0] > 0)
        #expect(svd.d[1] > 0)
        #expect(svd.d[0] >= svd.d[1])

        // Reconstruct A from SVD: A ≈ U * Σ * V^T
        let Sigma = Matrix(svd.U.cols, svd.V.rows, 0.0)
        for i in 0..<min(svd.d.count, min(Sigma.rows, Sigma.cols)) {
            Sigma[i,i] = svd.d[i]
        }

        let reconstructed = svd.U .* Sigma .* svd.V.transpose

        // Check reconstruction is close to original
        let tolerance = 0.001
        for i in 0..<A.rows {
            for j in 0..<A.cols {
                #expect(abs(A[i,j] - reconstructed[i,j]) < tolerance)
            }
        }
    }

    @Test func testSVDSquareMatrix() throws {
        // A = [[3,1],[1,3]] is symmetric positive-definite with eigenvalues 4 and 2,
        // so its singular values are exactly 4 and 2.
        let A = Matrix(2, 2, Vector([3.0, 1.0, 1.0, 3.0]))

        let svd = try #require(SingularValueDecomposition(A), "SVD should not return nil")

        #expect(svd.U.rows == 2)
        #expect(svd.U.cols == 2)
        #expect(svd.d.count == 2)
        #expect(svd.V.rows == 2)

        // Singular values, descending.
        #expect(isApprox(svd.d[0], 4.0, tolerance: 1e-6))
        #expect(isApprox(svd.d[1], 2.0, tolerance: 1e-6))

        // U and V must be orthonormal: UᵀU ≈ I and VᵀV ≈ I.
        let utu = svd.U.transpose .* svd.U
        let vtv = svd.V.transpose .* svd.V
        for i in 0..<2 {
            for j in 0..<2 {
                let expected = (i == j) ? 1.0 : 0.0
                #expect(isApprox(utu[i, j], expected, tolerance: 1e-6), "UᵀU should be identity")
                #expect(isApprox(vtv[i, j], expected, tolerance: 1e-6), "VᵀV should be identity")
            }
        }

        // Reconstruction: A ≈ U Σ Vᵀ.
        let sigma = Matrix.DiagonalMatrix(diagonal: svd.d)
        let reconstructed = svd.U .* sigma .* svd.V.transpose
        for i in 0..<2 {
            for j in 0..<2 {
                #expect(isApprox(A[i, j], reconstructed[i, j], tolerance: 1e-6))
            }
        }
    }

    @Test func testPCRotation() {
        // Test PCA on a simple dataset
        // Create a data matrix with some variance
        let X = Matrix(4, 2, Vector([1.0, 2.0, 2.0, 3.0, 3.0, 4.0, 4.0, 5.0]))

        guard let pca = PCRotation(X) else {
            Issue.record("PCRotation should not return nil")
            return
        }

        // Check returned components
        #expect(pca.d.count > 0, "Should have eigenvalues")
        #expect(pca.V.rows > 0, "Should have rotation matrix")
        #expect(pca.X.rows == X.rows, "Rotated data should have same number of rows")

        // Eigenvalues should be positive
        for val in pca.d {
            #expect(val >= 0, "Eigenvalues should be non-negative")
        }

        // First eigenvalue should be largest
        if pca.d.count > 1 {
            #expect(pca.d[0] >= pca.d[1], "Eigenvalues should be in descending order")
        }
    }

    @Test func testPRComp() {
        // Test prcomp equivalent function
        let X = Matrix(5, 3, Vector([
            2.5, 2.4, 1.0,
            0.5, 0.7, 1.5,
            2.2, 2.9, 2.0,
            1.9, 2.2, 1.8,
            3.1, 3.0, 2.2
        ]))

        guard let pca = PRComp(X) else {
            Issue.record("PRComp should not return nil")
            return
        }

        // Check standard deviations are positive
        for sd in pca.sdev {
            #expect(sd >= 0, "Standard deviations should be non-negative")
        }

        // Check rotation matrix dimensions
        #expect(pca.rotation.rows == X.cols, "Rotation should have cols of X as rows")

        // Check PC scores dimensions
        #expect(pca.x.rows == X.rows, "PC scores should have same rows as input")
        #expect(pca.x.cols == pca.rotation.cols, "PC scores cols should match rotation cols")

        // The rotation (loadings) matrix must be orthonormal: RᵀR ≈ I.
        let rtr = pca.rotation.transpose .* pca.rotation
        for i in 0..<rtr.rows {
            for j in 0..<rtr.cols {
                let expected = (i == j) ? 1.0 : 0.0
                #expect(isApprox(rtr[i, j], expected, tolerance: 1e-6),
                        "Rotation matrix should be orthonormal")
            }
        }

        // Reconstruction invariant: scores · rotationᵀ must recover the centered data.
        let centered = Matrix(X.rows, X.cols, X.values)
        centered.center()
        let recovered = pca.x .* pca.rotation.transpose
        for i in 0..<X.rows {
            for j in 0..<X.cols {
                #expect(isApprox(recovered[i, j], centered[i, j], tolerance: 1e-6),
                        "scores · rotationᵀ should reconstruct the centered data")
            }
        }
    }

    @Test func testMatrixCenter() {
        let M = Matrix(3, 2, Vector([1.0, 4.0, 2.0, 5.0, 3.0, 6.0]))
        M.center()

        // After centering, column means should be approximately 0
        let colMeans = M.colSum / Double(M.rows)
        let tolerance = 0.0001

        for mean in colMeans {
            #expect(abs(mean) < tolerance, "Column mean should be near zero after centering")
        }
    }

    @Test func testDominantEigenvector() {
        // Test with a simple symmetric matrix
        let A = Matrix(3, 3, Vector([4.0, 1.0, 1.0, 1.0, 4.0, 1.0, 1.0, 1.0, 4.0]))

        guard let eigenvector = DominantEigenvector(A: A) else {
            Issue.record("DominantEigenvector should not return nil for valid matrix")
            return
        }

        #expect(eigenvector.count == 3, "Eigenvector should have correct length")

        // Eigenvector should be normalized (magnitude = 1)
        let magnitude = sqrt(eigenvector.map { $0 * $0 }.sum)
        #expect(abs(magnitude - 1.0) < 0.0001, "Eigenvector should be normalized")
    }

    @Test func testDiagonalMatrix() {
        let diagonal = Vector([1.0, 2.0, 3.0, 4.0])
        let D = Matrix.DiagonalMatrix(diagonal: diagonal)

        #expect(D.rows == 4)
        #expect(D.cols == 4)

        // Check diagonal elements
        for i in 0..<4 {
            #expect(D[i,i] == diagonal[i])
        }

        // Check off-diagonal elements are zero
        for i in 0..<4 {
            for j in 0..<4 {
                if i != j {
                    #expect(D[i,j] == 0.0)
                }
            }
        }
    }

    @Test func testSubmatrix() {
        let M = Matrix(4, 4, Vector([
            1.0, 2.0, 3.0, 4.0,
            5.0, 6.0, 7.0, 8.0,
            9.0, 10.0, 11.0, 12.0,
            13.0, 14.0, 15.0, 16.0
        ]))

        let sub = M.submatrix([0, 2], [1, 3])

        #expect(sub.rows == 2)
        #expect(sub.cols == 2)
        #expect(sub[0,0] == 2.0)  // M[0,1]
        #expect(sub[0,1] == 4.0)  // M[0,3]
        #expect(sub[1,0] == 10.0) // M[2,1]
        #expect(sub[1,1] == 12.0) // M[2,3]
    }

    @Test func testGetRowGetCol() {
        let M = Matrix(3, 3, Vector([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0]))

        let row1 = M.getRow(r: 1)
        #expect(row1.count == 3)
        #expect(row1 == [4.0, 5.0, 6.0])

        let col2 = M.getCol(c: 2)
        #expect(col2.count == 3)
        #expect(col2 == [3.0, 6.0, 9.0])
    }
}
