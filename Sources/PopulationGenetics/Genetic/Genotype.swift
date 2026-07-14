//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Genotype.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 5/30/25.
//

import Foundation
import SwiftUI

/// Represents diploid genetic information for an individual at a specific locus.
///
/// A `Genotype` stores two alleles (left and right) representing the diploid state,
/// along with lineage tracking to determine parental origin of each allele.
/// Supports haploid, diploid, and empty states.
public struct Genotype: Codable, Hashable, Sendable, Identifiable {
    /// Unique identifier for this genotype.
    public var id: UUID

    /// The first allele in the diploid pair (lexicographically sorted when created via mating).
    public var leftAllele: String

    /// The second allele in the diploid pair (lexicographically sorted when created via mating).
    public var rightAllele: String

    /// Lineage tracking for the left allele. See `MaternalLineage`, `PaternalLineage`, etc.
    public var leftLineage: Int

    /// Lineage tracking for the right allele. See `MaternalLineage`, `PaternalLineage`, etc.
    public var rightLineage: Int

    /// Initializes a new genotype with the specified alleles and lineage.
    ///
    /// - Parameters:
    ///   - leftAllele: The first allele string.
    ///   - rightAllele: The second allele string.
    ///   - leftLingage: Lineage tracking for the left allele (defaults to `UnknownLineage`).
    ///   - rightLineage: Lineage tracking for the right allele (defaults to `UnknownLineage`).
    public init(leftAllele: String, rightAllele: String, leftLingage: Int = Genotype.UnknownLineage, rightLineage: Int = Genotype.UnknownLineage) {
        self.id = UUID()
        self.leftAllele = leftAllele
        self.rightAllele = rightAllele
        self.leftLineage = leftLingage
        self.rightLineage = rightLineage
    }

    /// Returns the ploidy level of this genotype.
    ///
    /// - Returns: `Empty` (0) if both alleles are empty, `Haploid` (1) if one allele is empty,
    ///   or `Diploid` (2) if both alleles are present.
    public var ploidy: Int {
        if isEmpty { return Genotype.Empty }
        else if leftAllele.isEmpty || rightAllele.isEmpty { return Genotype.Haploid }
        else { return Genotype.Diploid }
    }

    /// Indicates whether this genotype has no alleles.
    public var isEmpty: Bool {
        return leftAllele.isEmpty && rightAllele.isEmpty
    }

    /// Indicates whether this genotype is heterozygous (two different alleles).
    public var isHeterozygote: Bool {
        return !isEmpty && leftAllele != rightAllele
    }

}

extension Genotype: Equatable {

    /// Determines if two genotypes have equivalent alleles.
    ///
    /// Two genotypes are equal if they have matching left and right alleles;
    /// lineage is not considered part of identity.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand genotype.
    ///   - rhs: The right-hand genotype.
    /// - Returns: `true` if alleles match, `false` otherwise.
    static public func == (lhs: Genotype, rhs: Genotype) -> Bool {
        return lhs.leftAllele == rhs.leftAllele && lhs.rightAllele == rhs.rightAllele
    }

}

extension Genotype: CustomStringConvertible {

    /// Returns a string representation of the genotype in the format "leftAllele:rightAllele".
    public var description: String {
        return "\(leftAllele):\(rightAllele)"
    }

}


public extension Genotype {

    // MARK: - Lineage Constants

    /// Indicates the allele originated from the maternal parent (value: -1).
    static var MaternalLineage: Int { -1 }

    /// Indicates the allele's parental origin has not been determined (value: 0).
    static var UnknownLineage: Int { 0 }

    /// Indicates the allele originated from the paternal parent (value: 1).
    static var PaternalLineage: Int { 1 }

    /// Indicates the allele cannot be distinguished between parents (e.g., parent and offspring are both the same heterozygote) (value: 2).
    static var AmbiguousLineage: Int { 2 }

    /// Indicates the allele does not match either parent, suggesting misassignment (value: 3).
    static var ImpossibleLineage: Int { 3 }

    /// Returns a color associated with the given lineage value for visualization purposes.
    ///
    /// - Maternal: Pink
    /// - Paternal: Blue
    /// - Ambiguous: Orange
    /// - Impossible: Red
    /// - Unknown/default: Primary
    ///
    /// - Parameter lineage: The lineage value to map to a color.
    /// - Returns: A `Color` representing the lineage.
    static func colorForLineage( lineage: Int ) -> Color {
        switch lineage {
        case Genotype.MaternalLineage:
            return .pink
        case Genotype.PaternalLineage:
            return .blue
        case Genotype.AmbiguousLineage:
            return .orange
        case Genotype.ImpossibleLineage:
            return .red
        default:
            return .primary

        }
    }

    // MARK: - Ploidy Constants

    /// Indicates the genotype has no alleles (value: 0).
    static var Empty: Int { 0 }

    /// Indicates the genotype has one allele (haploid) (value: 1).
    static var Haploid: Int { 1 }

    /// Indicates the genotype has two alleles (diploid) (value: 2).
    static var Diploid: Int { 2 }

}
