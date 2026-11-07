//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AllelePairText.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The two alleles of a diploid genotype as text, while it is being edited.
///
/// Every editor splits and joins genotypes the same way through this, whatever its platform.
public struct AllelePairText: Equatable, Sendable {
    /// The left allele.
    public var left: String
    /// The right allele.
    public var right: String

    /// Creates a pair.
    ///
    /// - Parameters:
    ///   - left: The left allele.
    ///   - right: The right allele.
    public init(left: String = "", right: String = "") {
        self.left = left
        self.right = right
    }

    /// Splits a genotype.
    ///
    /// - Parameters:
    ///   - value: The joined genotype, such as `01:02`, or `""` for none.
    ///   - separator: The text between the alleles.
    public init(value: String, separator: String) {
        let parts = value.components(separatedBy: separator)
        self.init(left: parts.count == 2 ? parts[0] : "", right: parts.count == 2 ? parts[1] : "")
    }

    /// Joins the alleles, ignoring surrounding spaces.
    ///
    /// - Parameter separator: The text between the alleles.
    /// - Returns: The joined genotype, or `""` when both alleles are empty.
    public func value(separator: String) -> String {
        let left = left.trimmingCharacters(in: .whitespaces)
        let right = right.trimmingCharacters(in: .whitespaces)
        return left.isEmpty && right.isEmpty ? "" : left + separator + right
    }
}
