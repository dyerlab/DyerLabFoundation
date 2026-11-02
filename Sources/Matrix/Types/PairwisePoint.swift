//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PairwisePoint.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// One pair of units plotted as a point, e.g. a population pair's spatial
/// separation (`x`) against its genetic distance (`y`).
public struct PairwisePoint: Sendable, Equatable, Hashable {

    /// The first unit's name.
    public let from: String

    /// The second unit's name.
    public let to: String

    /// The predictor value for the pair.
    public let x: Double

    /// The response value for the pair.
    public let y: Double

    /// Creates a point.
    ///
    /// - Parameters:
    ///   - from: The first unit's name.
    ///   - to: The second unit's name.
    ///   - x: The predictor value.
    ///   - y: The response value.
    public init(from: String, to: String, x: Double, y: Double) {
        self.from = from
        self.to = to
        self.x = x
        self.y = y
    }
}
