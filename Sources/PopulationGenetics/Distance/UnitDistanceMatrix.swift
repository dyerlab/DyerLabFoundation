//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  UnitDistanceMatrix.swift
//  PopulationGenetics
//
//  The matrix a `DistanceResult` holds: any measure among named units. The
//  measure itself is in the result's `DistanceSpec`.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// Marks a `DistanceMatrix` as holding one of ``DistanceSpec/Measure``'s distances.
public enum UnitDistanceKind: PairwiseMeasure {
    /// The column name used in combined exports.
    public static let columnName = "Distance"
}

/// A symmetric matrix of pairwise distances among named individuals or strata.
public typealias UnitDistanceMatrix = DistanceMatrix<UnitDistanceKind>
