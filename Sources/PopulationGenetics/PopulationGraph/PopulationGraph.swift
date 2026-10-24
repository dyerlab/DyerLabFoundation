//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopulationGraph.swift
//  PopulationGenetics
//
//  A direct, line-by-line port of gstudio's `popgraph()` (Dyer & Nason 2004)
//  — the population-graph-construction method built on canonical discriminant
//  analysis and conditional (partial-correlation) genetic covariance among
//  population centroids, rather than a simple pairwise-distance/threshold
//  network. Ported for numerical identity with the R implementation; see
//  `~/Coding/gstudio/R/popgraph.R` for the reference.
//
//  Created by Rodney Dyer on 2026.08.26.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix
import Graph

/// Builds a population graph (Dyer & Nason 2004) from a multivariate data
/// matrix and a population/stratum label per row.
///
/// A direct port of gstudio's `popgraph(x, groups, alpha, tol)`. `x` is
/// typically produced by `GenotypeMatrix.multivariateMatrix()`, but any
/// numeric individuals×variables matrix works, matching R's `popgraph()`
/// accepting any numeric matrix (traditionally from gstudio's `to_mv()`).
///
/// - Parameters:
///   - x: An N×P numeric matrix (N individuals, P variables).
///   - groups: The population/stratum label for each of `x`'s `N` rows.
///   - alpha: Significance level for edge retention (default `0.05`).
///   - tol: Tolerance for retaining rotated/discriminant variables
///     (default `1.0e-4`).
/// - Returns: The population graph — one node per distinct group, sized by
///   within-group variance and connected by edges surviving the partial-
///   correlation chi-square test — or `nil` if any underlying decomposition
///   (PCA/SVD) fails.
public func PopulationGraph(x: Matrix, groups: [String], alpha: Double = 0.05, tol: Double = 1.0e-4) -> Graph? {
    guard let core = popgraphCore(x: x, groups: groups, alpha: alpha, tol: tol) else { return nil }
    return Graph(adjacency: core.D, weighted: true, nodeSize: core.nodeSize)
}

/// The full conditional-distance matrix under `alpha = 1` — gstudio's
/// `popgraph(x, groups, alpha = 1)` followed by `to_matrix(mode = "edge weight")`.
/// With `alpha = 1` the topology threshold retains every group pair (barring
/// an exact-zero partial correlation), so this is the same distance matrix
/// `PopulationGraph(x:groups:alpha:tol:)` thresholds down to a sparser graph,
/// labeled by group name.
///
/// Used by the genotype-driven resampling ports (`asymmetry_permutation`,
/// `asymmetry_ci`) which need to look up a re-estimated edge weight by
/// group pair rather than build a `Graph`.
///
/// - Parameters:
///   - x: An N×P numeric matrix (N individuals, P variables).
///   - groups: The population/stratum label for each of `x`'s `N` rows.
///   - tol: Tolerance for retaining rotated/discriminant variables (default `1.0e-4`).
/// - Returns: The `K×K` labeled distance matrix (`rowNames`/`colNames` are the
///   sorted group names), or `nil` under the same conditions as
///   `PopulationGraph(x:groups:alpha:tol:)`.
func PopulationGraphConditionalDistanceMatrix(x: Matrix, groups: [String], tol: Double = 1.0e-4) -> Matrix? {
    popgraphCore(x: x, groups: groups, alpha: 1.0, tol: tol)?.D
}

/// The shared computation behind `PopulationGraph(x:groups:alpha:tol:)` and
/// `PopulationGraphConditionalDistanceMatrix(x:groups:tol:)` — a direct port
/// of gstudio's `popgraph()` up to (and including) its `alpha`-threshold step,
/// stopping short of building the `Graph`.
private func popgraphCore(x: Matrix,
                          groups: [String],
                          alpha: Double,
                          tol: Double) -> (D: Matrix, sortedGroups: [String], nodeSize: [Int: Double])? {
    precondition(groups.count == x.rows, "groups must have one label per row of x")

    let N = Double(groups.count)
    let sortedGroups = Array(Set(groups)).sorted()
    let K = sortedGroups.count
    let counts = sortedGroups.map { group in Double(groups.filter { $0 == group }.count) }
    let priors = counts.map { $0 / N }
    let critVal = chiSquareQuantileOneDF(1.0 - alpha)

    // mv <- pcfit$x[, pcfit$sdev > tol]
    guard let pcfit = PRComp(x) else { return nil }
    let keepCols = pcfit.sdev.indices.filter { pcfit.sdev[$0] > tol }
    let mv = pcfit.x.submatrix(Array(0..<pcfit.x.rows), keepCols)
    let P = mv.cols

    // pop.means, sigma.w
    let popMeans = mv.groupMeans(strata: groups)
    let residual = mv - mv.groupMeansBroadcast(strata: groups)
    let sigmaW = (0..<P).map { c in sqrt(residual.getCol(c: c).variance) }

    // scaling <- diag(1/sigma.w); X <- sqrt(fac) * residual %*% scaling
    var scaling = Matrix.DiagonalMatrix(diagonal: sigmaW.map { 1.0 / $0 })
    let fac = 1.0 / (N - Double(K))
    let X1 = (residual * sqrt(fac)) .* scaling

    guard let svd1 = SingularValueDecomposition(X1) else { return nil }
    let rank1 = svd1.d.filter { $0 > tol }.count
    let V1 = svd1.V.submatrix(Array(0..<svd1.V.rows), Array(0..<rank1))
    let Dinv1 = Matrix.DiagonalMatrix(diagonal: svd1.d[0..<rank1].map { 1.0 / $0 })
    scaling = scaling .* V1 .* Dinv1

    // mu <- colSums(Pop.priors %*% pop.means) == mv's plain grand column mean
    let mu = mv.colSum / Double(mv.rows)

    // X <- sqrt(N*priors/(K-1)) * scale(pop.means, center=mu) %*% scaling
    let centeredPopMeans = popMeans - broadcastRow(mu, rows: K)
    let weights2 = priors.map { sqrt(N * $0 / Double(K - 1)) }
    let X2 = scaleRows(centeredPopMeans .* scaling, by: weights2)

    guard let svd2 = SingularValueDecomposition(X2) else { return nil }
    let rank2 = svd2.d.filter { $0 > tol * svd2.d[0] }.count
    let V2 = svd2.V.submatrix(Array(0..<svd2.V.rows), Array(0..<rank2))
    scaling = scaling .* V2

    // means <- colMeans(pop.means) (unweighted across the K groups)
    let means = (0..<P).map { c in (0..<K).reduce(0.0) { $0 + popMeans[$1, c] } / Double(K) }

    // LDValues <- scale(mv, center=means) %*% scaling
    let ldValues = (mv - broadcastRow(means, rows: mv.rows)) .* scaling

    let allLD = ldValues.groupMeans(strata: groups)
    let allSD = ldValues.centroidVariance(strata: groups)
    let D = allLD.distanceMatrix
    D.rowNames = sortedGroups
    D.colNames = sortedGroups

    // Gower double-centering: distance -> covariance
    let C = D.asCovariance

    let correlation = Matrix(K, K, 1.0)
    for i in 0..<K {
        for j in 0..<K where i != j {
            correlation[i, j] = C[i, j] / sqrt(C[i, i] * C[j, j])
        }
    }

    // MASS::ginv(R) is an SVD-based Moore-Penrose pseudo-inverse, not a plain
    // LU inverse — required here since the correlation matrix among K group
    // centroids is routinely rank-deficient (its rank is capped by the
    // discriminant-space dimensionality, which is usually < K-1).
    let RI = MoorePenroseInverse(correlation)
    let partial = Matrix(K, K, 1.0)
    for i in 0..<K {
        for j in 0..<K where i != j {
            partial[i, j] = -1.0 * RI[i, j] / sqrt(RI[i, i] * RI[j, j])
        }
    }

    let eed = Matrix(K, K, 0.0)
    for i in 0..<K {
        for j in 0..<K {
            let sri = max(0.0, 1.0 - partial[i, j] * partial[i, j])
            eed[i, j] = -N * log(sri)
        }
    }

    for i in 0..<K {
        for j in 0..<K where eed[i, j] <= critVal {
            D[i, j] = 0.0
        }
    }

    // popSD <- scale(allSD, center=min(allSD), scale=TRUE) * 5 + 5
    let minSD = allSD.min() ?? 0.0
    let centeredSD = allSD.map { $0 - minSD }
    let divisor = sqrt(centeredSD.map { $0 * $0 }.reduce(0.0, +) / Double(K - 1))
    let nodeSize = Dictionary(uniqueKeysWithValues: centeredSD.enumerated().map { index, value in
        (index, (value / divisor) * 5.0 + 5.0)
    })

    return (D: D, sortedGroups: sortedGroups, nodeSize: nodeSize)
}

/// A matrix with `rows` copies of `v` as every row.
private func broadcastRow(_ v: Vector, rows: Int) -> Matrix {
    let result = Matrix(rows, v.count, 0.0)
    for r in 0..<rows {
        for c in 0..<v.count {
            result[r, c] = v[c]
        }
    }
    return result
}

/// Scales each row `i` of `m` by `weights[i]`.
private func scaleRows(_ m: Matrix, by weights: Vector) -> Matrix {
    let result = Matrix(m.rows, m.cols, 0.0)
    for r in 0..<m.rows {
        for c in 0..<m.cols {
            result[r, c] = m[r, c] * weights[r]
        }
    }
    return result
}
