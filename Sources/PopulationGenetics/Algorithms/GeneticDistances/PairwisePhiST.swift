//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PairwisePhiST.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

import Matrix

/// Pairwise Φ_ST between every pair of strata, computed by gathering each
/// pair's individuals out of an already-computed distance matrix rather than
/// recomputing distances from genotypes — the redundant cost of a naive
/// per-pair recomputation is every within-stratum individual pair being
/// recomputed once per *other* stratum it's compared against, at O(loci) per
/// pair; gathering from `distance` is O(1) per pair and never touches
/// genotypes again. `GeneticDistanceMatrix.submatrix(indices:)` doesn't
/// require `strata` to group contiguous individuals together — gather cost
/// is the same regardless of ordering.
///
/// Deliberately generic over what `distance`'s N individuals actually are:
/// the same call serves adult individuals or pollen-pool-recovered paternal
/// gametes, since both just produce an N×N `GeneticDistanceMatrix` plus a
/// group label per unit.
///
/// No significance testing — this returns point estimates only. Pairwise
/// Φ_ST already trades away power (each comparison sees only two strata's
/// worth of individuals), so permutation testing here would need
/// disproportionately many permutations per pair to say anything reliable;
/// callers wanting significance should use `AMOVA.permutationTest` directly
/// on the multi-group partition instead.
///
/// - Parameters:
///   - distance: A precomputed distance matrix. If it was built with
///     `MissingDataStrategy.impute`, every pairwise Φ_ST here shares that
///     same full-panel imputation reference — restricting imputation to
///     just each pair's own individuals would only inflate the
///     already-elevated variance pairwise estimates carry.
///   - strata: One stratum label per individual in `distance`; `strata.count`
///     must equal `distance.count`.
/// - Returns: A `PhiSTMatrix` over `strata`'s distinct values, naturally sorted.
public func pairwisePhiST(distance: GeneticDistanceMatrix, strata: [String]) -> PhiSTMatrix {
    precondition(strata.count == distance.count,
                 "pairwisePhiST: strata.count (\(strata.count)) must equal distance.count (\(distance.count))")

    var indicesByLabel: [String: [Int]] = [:]
    for (i, label) in strata.enumerated() {
        indicesByLabel[label, default: []].append(i)
    }
    let groupNames = indicesByLabel.keys.naturalSorted()

    var result = PhiSTMatrix(groupNames: groupNames)
    guard groupNames.count > 1 else { return result }

    for a in 0..<groupNames.count {
        let indicesA = indicesByLabel[groupNames[a]]!
        for b in (a + 1)..<groupNames.count {
            let indicesB = indicesByLabel[groupNames[b]]!
            let submatrix = distance.submatrix(indices: indicesA + indicesB)
            let partition = Array(repeating: 0, count: indicesA.count) + Array(repeating: 1, count: indicesB.count)
            result[a, b] = AMOVA(distance: submatrix).decompose(partition: partition).phi
        }
    }
    return result
}
