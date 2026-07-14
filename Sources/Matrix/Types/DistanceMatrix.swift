//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  DistanceMatrix.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 7/13/26.
//

/// Identifies what a `DistanceMatrix<Kind>` measures and how it's labeled
/// when exported — see `DataTable(pairwise:)`.
public protocol PairwiseMeasure {
    /// Column name used when this measure is exported as one column of a
    /// combined pairwise table.
    static var columnName: String { get }
}

/// Type-erased read access to any `DistanceMatrix<Kind>`, so matrices of
/// different measures (Φ_ST, great-circle distance, relatedness, genetic
/// structure, ...) can be joined into one combined export without the join
/// site needing to know every concrete `Kind` up front. See
/// `DataTable(pairwise:)`.
public protocol PairwiseMatrix: Sendable {
    var groupNames: [String] { get }
    var columnName: String { get }
    subscript(_ i: Int, _ j: Int) -> Double { get }
}

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
    public subscript(_ i: Int, _ j: Int) -> Double {
        get { storage[i, j] }
        set { storage[i, j] = newValue }
    }

    /// Symmetric read access by group name.
    ///
    /// - Returns: The value, or `nil` if either name isn't in `groupNames`.
    public subscript(_ name1: String, _ name2: String) -> Double? {
        guard let i = groupNames.firstIndex(of: name1), let j = groupNames.firstIndex(of: name2) else { return nil }
        return self[i, j]
    }

    /// This measure's export column name — `Kind.columnName`.
    public var columnName: String { Kind.columnName }

    /// A dense N×N representation (symmetric, zero diagonal).
    public func dense() -> [[Double]] {
        storage.dense()
    }
}
