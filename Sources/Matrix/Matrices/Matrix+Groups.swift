//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  Matrix+Groups.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Group-wise reductions on `Matrix` rows, keyed by an external group label
//  per row (a "strata" vector, same shape as the categorical grouping
//  `Matrix.DesignMatrix(strata:)` already consumes). These mirror R's
//  `tapply`-style per-group reductions used throughout canonical discriminant
//  analysis.
//

import Foundation

extension Matrix {

    /// The sorted, unique group labels — the row order used by `groupMeans`,
    /// `groupMeansBroadcast`, and `centroidVariance`, matching
    /// `DesignMatrix(strata:)`'s column ordering.
    private static func sortedGroups(_ strata: [String]) -> [String] {
        Array(Set(strata)).sorted()
    }

    /// Per-group column means: a K×P matrix (K = number of distinct groups)
    /// where row `k` holds the mean of every column over the rows belonging
    /// to group `k`. Row names are the sorted group labels.
    ///
    /// Implements R's `tapply(mv, list(groups, col(mv)), mean)` (`pop.means`).
    ///
    /// - Precondition: `strata.count == rows`.
    public func groupMeans(strata: [String]) -> Matrix {
        precondition(strata.count == rows, "strata must have one label per row")
        let groups = Self.sortedGroups(strata)
        let result = Matrix(groups.count, cols, 0.0)
        result.rowNames = groups
        result.colNames = colNames

        for (k, group) in groups.enumerated() {
            let rowIndices = strata.indices.filter { strata[$0] == group }
            let n = Double(rowIndices.count)
            for c in 0..<cols {
                let total = rowIndices.reduce(0.0) { $0 + self[$1, c] }
                result[k, c] = total / n
            }
        }
        return result
    }

    /// Every row replaced by its own group's column means — an N×P matrix
    /// the same shape as `self`. Implements R's `pop.means[groups,]`.
    ///
    /// Built from the existing group hat matrix: for a 0/1 group-indicator
    /// design, `IdempotentHatMatrix(strata:)[i,j] = 1/n_g` iff rows `i,j`
    /// share group `g`, so `H .* self` gives exactly the per-row group-mean
    /// broadcast.
    ///
    /// - Precondition: `strata.count == rows`.
    public func groupMeansBroadcast(strata: [String]) -> Matrix {
        precondition(strata.count == rows, "strata must have one label per row")
        let H = Matrix.IdempotentHatMatrix(strata: strata)
        return H .* self
    }

    /// Per-group within-group variance sum: a K-length vector (K = number of
    /// distinct groups, same order as `groupMeans`) where entry `k` is
    /// `sum(diag(cov(x_group_k)))` — the sum of each column's sample variance
    /// restricted to group `k`'s rows.
    ///
    /// Implements `centroid_variance()`.
    ///
    /// - Precondition: `strata.count == rows`.
    public func centroidVariance(strata: [String]) -> Vector {
        precondition(strata.count == rows, "strata must have one label per row")
        let groups = Self.sortedGroups(strata)
        var result = Vector(repeating: 0.0, count: groups.count)

        for (k, group) in groups.enumerated() {
            let rowIndices = strata.indices.filter { strata[$0] == group }
            var total = 0.0
            for c in 0..<cols {
                let column = Vector(rowIndices.map { self[$0, c] })
                total += column.variance
            }
            result[k] = total
        }
        return result
    }
}
