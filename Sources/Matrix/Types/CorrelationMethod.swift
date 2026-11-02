//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  CorrelationMethod.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// Which correlation coefficient to compute.
public enum CorrelationMethod: String, Sendable, Codable, CaseIterable {

    /// Pearson's product-moment correlation (`pearsonCorrelation`).
    case pearson

    /// Spearman's rank correlation (`spearmanCorrelation`).
    case spearman

    /// The correlation between two equal-length vectors.
    ///
    /// - Parameters:
    ///   - x: The first vector.
    ///   - y: The second vector.
    /// - Returns: The coefficient, or `.nan` if either vector is constant.
    public func correlation(_ x: Vector, _ y: Vector) -> Double {
        switch self {
        case .pearson: pearsonCorrelation(x, y)
        case .spearman: spearmanCorrelation(x, y)
        }
    }

    /// The coefficient's name for running text.
    public var displayName: String {
        switch self {
        case .pearson: "Pearson product-moment"
        case .spearman: "Spearman rank"
        }
    }
}
