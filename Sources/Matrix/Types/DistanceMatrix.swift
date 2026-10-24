//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DistanceMatrix.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.07.13.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// A symmetric matrix of a pairwise measure among named groups (typically
/// strata), stored as its upper triangle.
///
/// Generic over `Kind` so distinct measures stay separate, non-interchangeable
/// Swift types — `DistanceMatrix<PhiSTKind>` and `DistanceMatrix<GreatCircleKind>`
/// can't be passed to each other's call sites by accident — while sharing one
/// storage/access implementation and one path to `DataTable` export. Same
/// pattern as Foundation's `Measurement<UnitLength>` vs `Measurement<UnitDuration>`:
/// `Kind` is a phantom type parameter, never stored, used only to carry
/// `columnName` and keep instantiations distinct at compile time.
///
/// Built on `SymmetricUpperTriangle<Double>` for storage — the same shared
/// packed-triangle representation any other symmetric pairwise measure
/// (e.g. a domain's own individual-level accumulating distance matrix) can
/// build on.
public struct DistanceMatrix<Kind: PairwiseMeasure>: PairwiseMatrix, Sendable, Equatable {

    /// Names of the groups, in row/column order.
    public let groupNames: [String]

    private var storage: SymmetricUpperTriangle<Double>

    /// Creates a zero matrix for the given groups.
    ///
    /// - Parameter groupNames: Group names, in row/column order.
    public init(groupNames: [String]) {
        self.groupNames = groupNames
        self.storage = SymmetricUpperTriangle<Double>(count: groupNames.count)
    }

    /// Symmetric read/write access by row/column index; the diagonal always returns 0.
    ///
    /// - Parameters:
    ///   - i: Row index.
    ///   - j: Column index.
    /// - Returns: The distance between groups `i` and `j`.
    public subscript(_ i: Int, _ j: Int) -> Double {
        get { storage[i, j] }
        set { storage[i, j] = newValue }
    }

    /// Symmetric read access by group name.
    ///
    /// - Parameters:
    ///   - name1: The first group's name.
    ///   - name2: The second group's name.
    /// - Returns: The value, or `nil` if either name isn't in `groupNames`.
    public subscript(_ name1: String, _ name2: String) -> Double? {
        guard let i = groupNames.firstIndex(of: name1), let j = groupNames.firstIndex(of: name2) else { return nil }
        return self[i, j]
    }

    /// This measure's export column name — `Kind.columnName`.
    public var columnName: String { Kind.columnName }

    /// A dense N×N representation (symmetric, zero diagonal).
    ///
    /// - Returns: The distances as nested row arrays.
    public func dense() -> [[Double]] {
        storage.dense()
    }
}
