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
//  Created by Rodney Dyer on 4/23/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

import Foundation
import Matrix

// MARK: - Migration

/// Applies one round of migration to a set of populations using a row-stochastic migration matrix.
///
/// `matrix[i, j]` is the fraction of population *i* that emigrates to population *j*.
/// `matrix[i, i]` is the stay-home fraction.  Rows must sum to 1.0.
///
/// For each source row *i*, the population is shuffled once and emigrants are drawn
/// **without replacement** in column order — so the same individual cannot go to two
/// destinations in the same round.  The number of emigrants from *i* to *j* is:
///
/// ```
/// Int((matrix[i, j] * Double(populations[i].count)).rounded())
/// ```
///
/// Individual objects are not copied; only array membership changes.
/// Stratum membership in the data store is **not** updated here — update strata
/// after calling this function if downstream code relies on them.
///
/// - Parameters:
///   - populations: Dictionary of population name → `[Individual]`.
///     Keys must match `matrix.rowNames` exactly.
///   - matrix: K×K row-stochastic `Matrix` from the DyerLabFoundation Matrix module.
/// - Returns: New dictionary of population name → `[Individual]` after migration.
///
/// ## Example
///
/// ```swift
/// let migrated = applyMigration(populations: current, matrix: migMatrix)
/// ```
public func applyMigration(
    populations: [String: [Individual]],
    matrix: Matrix
) -> [String: [Individual]] {

    var result = populations

    for i in 0..<matrix.rows {
        let sourceName = matrix.rowNames[i]
        guard let source = result[sourceName], !source.isEmpty else { continue }

        let rowSum = (0..<matrix.cols).reduce(0.0) { $0 + matrix[i, $1] }
        precondition(abs(rowSum - 1.0) < 1e-9,
                     "applyMigration: row \(i) (\(sourceName)) sums to \(rowSum), not 1.0")

        // Shuffle source once so draws for multiple destinations don't overlap
        let shuffled = source.shuffled()
        var offset = 0

        for j in 0..<matrix.cols {
            guard i != j, matrix[i, j] > 0.0 else { continue }
            let destName = matrix.colNames[j]
            // Rounding each column's fraction independently can make the row's
            // counts sum to slightly more than `source.count` (e.g. two 0.5
            // columns over 3 individuals both round up to 2). Clamp to what's
            // actually left rather than silently dropping this destination's
            // emigrants entirely when the naive count would overflow.
            let requested = Int((matrix[i, j] * Double(source.count)).rounded())
            let count = min(requested, shuffled.count - offset)
            guard count > 0 else { continue }

            let movers = Array(shuffled[offset..<offset + count])
            offset += count
            result[destName, default: []].append(contentsOf: movers)
        }

        if offset > 0 {
            // Remove all emigrants from the source in one pass
            let emigrantIDs = Set(shuffled.prefix(offset).map { $0.id })
            result[sourceName] = source.filter { !emigrantIDs.contains($0.id) }
        }
    }

    return result
}
