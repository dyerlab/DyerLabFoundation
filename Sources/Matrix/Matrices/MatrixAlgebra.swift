//
//  MatrixAlgebra.swift
//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//
//
//  Created by Rodney Dyer on 6/10/21.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//


import Accelerate

/// Computes the generalized inverse of a square matrix.
///
/// Uses LU decomposition via LAPACK's `dgetrf` and `dgetri` routines from the Accelerate framework.
/// The generalized inverse satisfies: A × A⁻¹ ≈ I
///
/// - Parameter X: A square matrix
/// - Returns: The inverse matrix, or an empty matrix (0×0) if:
///   - The matrix is not square
///   - The matrix is singular (not invertible)
///   - LU factorization fails
///
/// ## Example
/// ```swift
/// let A = Matrix(2, 2, [4.0, 7.0, 2.0, 6.0])
/// let Ainv = GeneralizedInverse(A)
/// let I = A .* Ainv  // Should be approximately identity
/// ```
///
/// - Warning: If the matrix is nearly singular, results may be numerically unstable.
public func GeneralizedInverse(_ X: Matrix ) -> Matrix {
    
    if X.rows != X.cols {
        return Matrix(0,0)
    }
    
    let Y = Matrix( X.rows, X.cols, X.values )
    var M = Int32(X.rows)
    var N = M
    var LDA = N
    var pivot = [Int32](repeating: 0, count: Int(N))
    var wkOpt = Double(0.0)
    var lWork = Int32(-1)
    var error: Int32 = 0
    
    dgetrf_(&M, &N, &(Y.values), &LDA, &pivot, &error)

    if error != 0 {
        Logger().notice("Could not compute LU factorization (dgetrf_).")
        return Matrix(0,0)
    }
    
    /* Query and allocate the optimal workspace */
    dgetri_(&N, &(Y.values), &LDA, &pivot, &wkOpt, &lWork, &error)
    lWork = Int32(wkOpt)
    var work = Vector(repeating: 0.0, count: Int(lWork))
    
    /* Compute inversed matrix */
    dgetri_(&N, &(Y.values), &LDA, &pivot, &work, &lWork, &error)
    
    if error != 0 {
        Logger().notice("Could not invert matrix (dgetri_).")
        return Matrix(0,0)
    }

    return Y
}




/// Performs Principal Component Analysis (PCA) on a data matrix.
///
/// Computes PCA using Singular Value Decomposition after centering the data. The data matrix
/// is centered to have zero mean columns before decomposition.
///
/// - Parameter X: An N×P data matrix (N observations, P variables)
/// - Returns: A tuple containing:
///   - `d`: Vector of standard deviations (sqrt of eigenvalues)
///   - `V`: P×P matrix of eigenvectors (principal component loadings)
///   - `X`: N×P matrix of principal component scores
///
///   Returns `nil` if SVD fails.
///
/// ## Example
/// ```swift
/// let data = Matrix(100, 5, ...)  // 100 observations, 5 variables
/// if let pca = PCRotation(data) {
///     print("PC1 variance:", pca.d[0] * pca.d[0])
///     print("Loadings:", pca.V)
///     print("Scores:", pca.X)
/// }
/// ```
///
/// - Note: The returned eigenvalues are in descending order (PC1, PC2, ...).
public func PCRotation(_ X: Matrix ) -> (d: Vector, V: Matrix, X: Matrix)? {
    let A = Matrix(X.rows, X.cols, X.values)
    A.center()

    guard let s = SingularValueDecomposition( A ) else { return nil }

    let d = s.d / ( sqrt( max(1.0, Double( A.rows )-1.0)))
    let V = s.V
    let scores = X .* V

    return (d, V, scores)
}



/// Computes the Singular Value Decomposition (SVD) of a matrix.
///
/// Decomposes matrix A into: **A = U × Σ × V'** where:
/// - U contains the left singular vectors
/// - Σ is a diagonal matrix of singular values (returned as vector d)
/// - V contains the right singular vectors
///
/// Uses LAPACK's `dgesdd` (divide-and-conquer SVD) via Accelerate framework for optimal performance.
///
/// - Parameter A: An M×N matrix to decompose
/// - Returns: A tuple containing:
///   - `U`: M×M matrix of left singular vectors
///   - `d`: Vector of singular values in descending order
///   - `V`: N×K matrix of right singular vectors (K = min(M,N))
///
///   Returns `nil` if SVD computation fails.
///
/// ## Example
/// ```swift
/// let A = Matrix(5, 3, ...)
/// if let svd = SingularValueDecomposition(A) {
///     // Reconstruct: A ≈ U * diag(d) * V'
///     let Sigma = Matrix.DiagonalMatrix(diagonal: svd.d)
///     let reconstructed = svd.U .* Sigma .* svd.V.transpose
/// }
/// ```
///
/// - Note: Singular values are returned in descending order.
public func SingularValueDecomposition(_ A: Matrix) -> (U: Matrix, d: Vector, V: Matrix)? {
    var M = Int32(A.rows);
    var N = Int32(A.cols);
    
    var LDA = M;
    var LDU = M;
    var LDV = N;
    
    var wkOpt = Double(0.0)
    var lWork = Int32(-1)
    var iWork = [Int32](repeating: 0, count: Int(8 * min(M, N)))
    var error = Int32(0)
    
    var d = Vector(repeating: 0.0, count: Int( min(M, N) ) )
    
    let U = Matrix(Int(LDU), Int(M))
    let V = Matrix(Int(LDV), Int(N))
    
    // Query and allocate the optimal workspace
    let _A = A.transpose
    var jobz: Int8 = 65 // It is 'A'
    dgesdd_(&jobz,
            &M, &N,
            &_A.values,
            &LDA, &d,
            &U.values,
            &LDU,
            &V.values, &LDV,
            &wkOpt, &lWork, &iWork,
            &error)
    
    // Catch any error
    if error != 0 {
        let logger = Logger()
        logger.notice("Could not allocate workspace for SVD decomposition.")
        return nil
    }
    
    lWork = Int32(wkOpt)
    var work = Vector(repeating: 0.0, count: Int(lWork))
    
    // Compute the singular value decomposition
    dgesdd_(&jobz,
            &M, &N,
            &_A.values,
            &LDA, &d, &U.values,
            &LDU, &V.values,
            &LDV,
            &work, &lWork, &iWork,
            &error)
    
    // Catch any error
    if error != 0 {
        let logger = Logger()
        logger.notice("Could not compute SVD.")
        return nil
    }
    
    let rows = Array(0..<V.rows)
    let cols = Array(0..<d.count)
    return (U.transpose, d, V.submatrix( rows, cols ) )
    
    
}


// MARK: - Eigenvector Computation


/// Computes the dominant eigenvector using the power iteration method.
///
/// Iteratively computes the eigenvector corresponding to the largest eigenvalue (in magnitude)
/// of a square matrix. The eigenvector is normalized to unit length.
///
/// - Parameters:
///   - A: A square matrix
///   - tolerance: Convergence tolerance (default: 1e-6)
///   - maxIterations: Maximum iterations before giving up (default: 1000)
/// - Returns: The normalized dominant eigenvector, or `nil` if:
///   - Matrix is not square or empty
///   - Algorithm fails to converge
///   - Eigenvalue is zero
///
/// ## Example
/// ```swift
/// let A = Matrix(3, 3, [4.0, 1.0, 1.0, 1.0, 4.0, 1.0, 1.0, 1.0, 4.0])
/// if let v = DominantEigenvector(A: A) {
///     print("Dominant eigenvector:", v)
///     print("Magnitude:", v.magnitude)  // Should be ≈ 1.0
/// }
/// ```
///
/// - Note: For symmetric matrices, the dominant eigenvector corresponds to the largest eigenvalue.
///   For non-symmetric matrices, this finds the eigenvector for the eigenvalue with largest magnitude.
public func DominantEigenvector(A: Matrix, tolerance: Double = 1e-6, maxIterations: Int = 1000) -> Vector? {
    
    guard A.rows == A.cols, A.rows > 0 else { return nil }
    
    // Start with a random vector
    var v = Vector((0..<A.cols).map { _ in Double.random(in: -1.0...1.0) })
    
    // Normalize
    let norm = sqrt(v.reduce(0.0) { $0 + $1 * $1 })
    if norm == 0.0 { return nil }
    v = v.map { $0 / norm }
    var prevV = v
    
    for _ in 0..<maxIterations {
        // Multiply matrix by vector (square matrix, so rows == cols == v.count)
        var nextV = A .* v
        // Normalize
        let nextNorm = sqrt(nextV.reduce(0.0) { $0 + $1 * $1 })
        if nextNorm == 0.0 { return nil }
        nextV = nextV.map { $0 / nextNorm }
        // Check for convergence
        let diff = zip(nextV, prevV).map { abs($0 - $1) }.max() ?? 0.0
        if diff < tolerance {
            return nextV
        }
        prevV = nextV
        v = nextV
    }
    
    // If not converged, return nil
    return nil
}




/// Performs Principal Component Analysis matching R's `prcomp()` function.
///
/// Equivalent to R's `prcomp(x, retx = TRUE, center = TRUE, scale. = FALSE)`.
/// Centers data to zero mean before decomposition but does not scale to unit variance.
///
/// - Parameter X: An N×P data matrix (N observations, P variables)
/// - Returns: A tuple containing:
///   - `sdev`: Vector of standard deviations (sqrt of eigenvalues) in descending order
///   - `rotation`: P×P matrix of eigenvectors (variable loadings on principal components)
///   - `x`: N×P matrix of principal component scores (rotated data)
///
///   Returns `nil` if SVD fails.
///
/// ## Example
/// ```swift
/// let data = Matrix(50, 4, ...)
/// if let pca = PRComp(data) {
///     // Variance explained by PC1
///     let var1 = pca.sdev[0] * pca.sdev[0]
///
///     // Total variance
///     let totalVar = pca.sdev.map { $0 * $0 }.sum
///
///     // Proportion variance explained
///     let propVar = var1 / totalVar
/// }
/// ```
///
/// - Note: Compatible with R output for easy cross-platform validation
public func PRComp(_ X: Matrix) -> (sdev: Vector, rotation: Matrix, x: Matrix)? {
    // Center the data
    let centered = Matrix(X.rows, X.cols, X.values)
    centered.center()

    // Perform SVD
    guard let s = SingularValueDecomposition(centered) else { return nil }

    // s.d contains the singular values. Standard deviations = s.d / sqrt(n - 1)
    let n = Double(centered.rows)
    let sdev = s.d / sqrt(n - 1.0)

    // s.V is the rotation matrix (eigenvectors)
    let rotation = s.V

    // Principal component scores = X_centered * rotation
    let x = centered .* rotation

    return (sdev, rotation, x)
}
