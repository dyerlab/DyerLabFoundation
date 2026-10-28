//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PairwiseMatrix.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.07.13.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// Type-erased read access to any `DistanceMatrix<Kind>`, so matrices of
/// different measures (Φ_ST, great-circle distance, relatedness, genetic
/// structure, ...) can be joined into one combined export without the join
/// site needing to know every concrete `Kind` up front. See
/// `DataTable(pairwise:)`.
public protocol PairwiseMatrix: Sendable {
    /// The group labels, in row and column order.
    var groupNames: [String] { get }
    /// The measure's column name in a combined export.
    var columnName: String { get }
    /// The value between groups `i` and `j`.
    ///
    /// - Parameters:
    ///   - i: Row index.
    ///   - j: Column index.
    /// - Returns: The pairwise value.
    subscript(_ i: Int, _ j: Int) -> Double { get }
}
