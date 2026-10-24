//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PhiSTMatrix.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.07.13.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// Marks a `DistanceMatrix` as holding pairwise Φ_ST estimates. See `PairwisePhiST`.
public enum PhiSTKind: PairwiseMeasure {
    /// The column name used for Φ_ST in combined exports.
    public static let columnName = "PhiST"
}

/// A symmetric matrix of pairwise Φ_ST estimates among strata.
public typealias PhiSTMatrix = DistanceMatrix<PhiSTKind>
