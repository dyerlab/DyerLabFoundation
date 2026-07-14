//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GeneticDistanceMatrix.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 6/28/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

import Matrix

/// A symmetric inter-individual distance matrix, indexed by ordinal (not
/// name) and accumulable across loci — the genetics-specific counterpart to
/// Matrix's own `DistanceMatrix<Kind>` (named groups, no accumulation).
/// Built on the same shared `SymmetricUpperTriangle<Double>` storage; this
/// type only adds ordinal indexing and per-locus accumulation semantics
/// that only make sense for raw individual-level distances, not for a
/// final, derived, group-level measure.
public struct GeneticDistanceMatrix: Sendable, Equatable {

    private var storage: SymmetricUpperTriangle<Double>

    /// Number of individuals.
    public var count: Int { storage.count }

    /// Creates a zero distance matrix for `count` individuals.
    ///
    /// - Parameter count: Number of individuals; must be ≥ 0.
    public init(count: Int) {
        self.storage = SymmetricUpperTriangle<Double>(count: count)
    }

    /// Symmetric read/write access to a pairwise distance; the diagonal always returns 0.
    ///
    /// - Parameters:
    ///   - i: Row index (0..<count).
    ///   - j: Column index (0..<count).
    /// - Returns: The squared genetic distance between individuals `i` and `j`.
    public subscript(_ i: Int, _ j: Int) -> Double {
        get { storage[i, j] }
        set { storage[i, j] = newValue }
    }

    /// Adds another matrix's distances in place (locus accumulation).
    ///
    /// - Parameter other: A same-sized matrix whose distances are added element-wise.
    public mutating func add(_ other: GeneticDistanceMatrix) {
        storage.add(other.storage)
    }

    /// Subtracts another matrix's distances in place (drop a locus).
    ///
    /// - Parameter other: A same-sized matrix whose distances are subtracted element-wise.
    public mutating func subtract(_ other: GeneticDistanceMatrix) {
        storage.subtract(other.storage)
    }

    /// Extracts the distances among an arbitrary subset of individuals into a
    /// new, smaller matrix — e.g. pulling out just the individuals belonging
    /// to a pair of strata for pairwise Φ_ST (see `pairwisePhiST`), without
    /// recomputing anything from genotypes. Storage is a packed upper
    /// triangle addressed by computed offset, so `indices` need not be
    /// contiguous or sorted — a scattered gather costs the same as a
    /// contiguous one.
    ///
    /// - Parameter indices: Individual indices (0..<count) to include, in
    ///   the order they should appear in the result.
    /// - Returns: A `GeneticDistanceMatrix` of size `indices.count`, where
    ///   result `[a, b]` is `self[indices[a], indices[b]]`.
    public func submatrix(indices: [Int]) -> GeneticDistanceMatrix {
        var result = GeneticDistanceMatrix(count: indices.count)
        result.storage = storage.submatrix(indices: indices)
        return result
    }

    /// A dense N×N representation (symmetric, zero diagonal), e.g. for AMOVA.
    public func dense() -> [[Double]] {
        storage.dense()
    }
}
