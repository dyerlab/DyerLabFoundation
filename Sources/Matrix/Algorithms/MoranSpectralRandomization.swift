//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MoranSpectralRandomization.swift
//  Matrix
//
//  A port of gstudio's `msr_null()` — Moran spectral randomization, the
//  "singleton" algorithm of Wagner & Dray (2015), itself a native port of
//  `adespatial::msr(x, listw, method = "singleton")` with
//  `spdep::mat2listw(W, style = "B")` weights. See
//  `~/Coding/gstudio/R/msr_null.R`.
//
//  Reproducibility: each replicate is Σ_k s_k r_k v_k, with v_k a Moran
//  eigenvector, r_k = cor(z, v_k) and s_k a random sign. Flipping v_k flips
//  r_k, so every term — and the replicate — is independent of the (arbitrary)
//  eigenvector signs. With distinct eigenvalues the result therefore matches R
//  for the same seed up to floating-point rounding; within a repeated
//  eigenvalue the basis is arbitrary, and replicates agree with R only in
//  distribution.
//
//  Created by Rodney Dyer on 2026.10.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Null replicates of a node-level variable that preserve its spectral
/// structure on a spatial weighting matrix — a port of gstudio's `msr_null()`
/// (Moran spectral randomization, Wagner & Dray 2015, "singleton" method).
///
/// `z` is expanded on the Moran eigenvector maps (MEMs) of the doubly-centred
/// weight matrix, and each replicate gives every coefficient an independent
/// random sign, so each replicate keeps the observed mean, variance and
/// spectral power.
///
/// - Parameters:
///   - z: One value per node.
///   - weights: A symmetric, non-negative `n × n` weight matrix; asymmetric
///     input is symmetrised as `(W + Wᵀ)/2`.
///   - replicates: Number of null replicates (R's `nrepet`).
///   - rng: The generator, consumed as R's `sample(c(-1, 1), 1)` once per
///     eigenvector per replicate.
/// - Returns: An `n × replicates` matrix (one replicate per column), or `nil`
///   if `n < 3`, `weights` is not `n × n`, the weight matrix has no null
///   eigenvalue (gstudio: "Illegal weight matrix"), or the eigendecomposition
///   fails.
public func MoranSpectralRandomization(_ z: Vector,
                                       weights: Matrix,
                                       replicates: Int,
                                       using rng: inout RMersenneTwister) -> Matrix? {
    let n = z.count
    guard n >= 3, weights.rows == n, weights.cols == n,
          let mem = moranEigenvectorBasis(weights) else { return nil }

    let r = (0..<mem.cols).map { pearsonCorrelation(z, mem.getCol(c: $0)) }
    let zMean = z.reduce(0, +) / Double(n)
    let zSD = (z.reduce(0) { $0 + ($1 - zMean) * ($1 - zMean) } / Double(n - 1)).squareRoot()
    let scale = Double(n - 1).squareRoot()

    let out = Matrix(n, replicates, 0.0)
    for k in 0..<replicates {
        let a = r.map { rng.sample([-1.0, 1.0], size: 1)[0] * $0 }       // adespatial genbysingleton()
        for i in 0..<n {
            var projection = 0.0
            for (j, coefficient) in a.enumerated() { projection += mem[i, j] * coefficient }
            out[i, k] = scale * projection * zSD + zMean
        }
    }
    return out
}

/// Seeded convenience for ``MoranSpectralRandomization(_:weights:replicates:using:)``,
/// equivalent to R's `set.seed(seed); msr_null(z, W, nrepet)`.
///
/// - Parameters:
///   - z: The observed variable, one value per site.
///   - weights: An `n × n` spatial weight matrix.
///   - replicates: Number of randomized replicates.
///   - seed: R `set.seed()` value.
/// - Returns: An `n × replicates` matrix, one randomized replicate per column, or `nil` under the same
///   conditions as the generator-based overload.
public func MoranSpectralRandomization(_ z: Vector,
                                       weights: Matrix,
                                       replicates: Int,
                                       seed: Int) -> Matrix? {
    var rng = RMersenneTwister(seed: seed)
    return MoranSpectralRandomization(z, weights: weights, replicates: replicates, using: &rng)
}

/// The orthonormal Moran eigenvector basis (`n − 1` columns, descending
/// eigenvalue order) of a weight matrix — gstudio's `.mem_basis()`, as
/// `adespatial::scores.listw(MEM.autocor = "all")`.
///
/// The weight matrix is doubly centred with uniform weights (`ade4::bicenter.wt`)
/// and eigendecomposed; the null eigenvector (the constant) is removed. If the
/// null eigenvalue is repeated, that eigenspace is re-orthonormalised against
/// the constant vector first (R's `qr.Q(qr(cbind(wt, V0)))`).
///
/// - Parameter weights: An `n × n` spatial weight matrix.
/// - Returns: An `n × (n − 1)` matrix, or `nil` if there is no null eigenvalue
///   or the eigendecomposition fails.
func moranEigenvectorBasis(_ weights: Matrix) -> Matrix? {
    let n = weights.rows
    let wt = 1.0 / Double(n)

    // Symmetrise ((W + Wᵀ)/2 is exact for an already symmetric W).
    var W = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
    for i in 0..<n { for j in 0..<n { W[i][j] = (weights[i, j] + weights[j, i]) / 2.0 } }

    // ade4::bicenter.wt with uniform row/column weights.
    let rowMean = (0..<n).map { j in (0..<n).reduce(0.0) { $0 + wt * W[$1][j] } }   // colSums(wt * W)
    var colMean = (0..<n).map { j in (0..<n).reduce(0.0) { $0 + wt * W[j][$1] } }   // colSums(wt * t(W))
    let grand = rowMean.reduce(0.0) { $0 + $1 * wt }
    colMean = colMean.map { $0 - grand }

    let X = Matrix(n, n, 0.0)
    let sqrtWt = wt.squareRoot()
    for i in 0..<n {
        for j in 0..<n {
            X[i, j] = (W[i][j] - rowMean[j] - colMean[i]) * sqrtWt * sqrtWt
        }
    }

    guard let eigen = SymmetricEigendecomposition(X) else { return nil }
    let maxAbs = eigen.values.map { abs($0) }.max() ?? 0
    guard maxAbs > 0 else { return nil }
    // isTRUE(all.equal(v, 0)) <=> |v| < sqrt(.Machine$double.eps).
    let tolerance = Double.ulpOfOne.squareRoot()
    let nullIndices = eigen.values.indices.filter { abs(eigen.values[$0] / maxAbs) < tolerance }
    guard let firstNull = nullIndices.first else { return nil }

    var columns = (0..<n).map { eigen.vectors.getCol(c: $0) }
    if nullIndices.count > 1 {
        // R: q <- qr.Q(qr(cbind(wt, V0))); V0 <- q[, -ncol(q)]. The first column
        // of q is the constant direction (it lands at nullIndices[0] and is
        // dropped below); the rest orthonormalise V0's first m − 1 columns
        // against it and each other (Gram-Schmidt spans the same subspace).
        var basis: [Vector] = [Vector(repeating: 1.0 / Double(n).squareRoot(), count: n)]
        for index in nullIndices.dropLast() {
            var v = columns[index]
            for q in basis {
                let projection = zip(v, q).reduce(0.0) { $0 + $1.0 * $1.1 }
                v = zip(v, q).map { $0 - projection * $1 }
            }
            let norm = v.reduce(0.0) { $0 + $1 * $1 }.squareRoot()
            basis.append(norm > 0 ? v.map { $0 / norm } : v)
        }
        for (position, index) in nullIndices.enumerated() { columns[index] = basis[position] }
    }

    let kept = (0..<n).filter { $0 != firstNull }
    let mem = Matrix(n, kept.count, 0.0)
    // adespatial divides by sqrt(wt) and msr by sqrt(n); with uniform weights
    // the two cancel exactly in value, kept here for fidelity to R.
    let rescale = 1.0 / sqrtWt / Double(n).squareRoot()
    for (column, index) in kept.enumerated() {
        for i in 0..<n { mem[i, column] = columns[index][i] * rescale }
    }
    return mem
}
