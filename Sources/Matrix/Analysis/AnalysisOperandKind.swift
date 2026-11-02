//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AnalysisOperandKind.swift
//  Matrix
//
//  An open tag rather than an enum, so modules above Matrix can describe
//  their own inputs (genotypes, maternal families) without routing new cases
//  through this target. Same shape as `AnalysisTag` and `LogType`.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// The kind of value an analysis operand holds.
///
/// Matrix defines the matrix-shaped kinds; any module can mint its own with a
/// `static let` extension.
public struct AnalysisOperandKind: Sendable, Equatable, Hashable, CustomStringConvertible {

    /// The kind's underlying label.
    public let rawValue: String

    /// Creates an operand kind with the given label.
    ///
    /// - Parameter rawValue: The kind's label.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// The kind's label.
    public var description: String { rawValue }

    /// A square `n × n` matrix of pairwise values among `n` units — a genetic,
    /// spatial or graph distance matrix.
    public static let pairwise = AnalysisOperandKind("pairwise")

    /// A group label per unit: the compact form of a model (design) matrix
    /// whose pairwise entries say whether two units share a group.
    public static let partition = AnalysisOperandKind("partition")

    /// A collection of units to resample, such as individuals or alleles.
    public static let sample = AnalysisOperandKind("sample")
}
