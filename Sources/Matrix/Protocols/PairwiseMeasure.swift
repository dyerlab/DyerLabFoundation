//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PairwiseMeasure.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.07.13.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// Identifies what a `DistanceMatrix<Kind>` measures and how it's labeled
/// when exported — see `DataTable(pairwise:)`.
public protocol PairwiseMeasure {
    /// Column name used when this measure is exported as one column of a
    /// combined pairwise table.
    static var columnName: String { get }
}
