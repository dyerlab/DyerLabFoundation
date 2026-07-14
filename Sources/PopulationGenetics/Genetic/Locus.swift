//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Locus.swift
//
//
//  Created by Rodney Dyer on 5/30/25.
//

import Foundation

/// Represents a genetic marker or locus in a population genetics dataset.
///
/// A `Locus` represents a specific location on a chromosome or contig where genetic variation
/// is measured. Each locus has a unique identifier, name, and optional physical location information.
/// The locus maintains references to all genotypes observed at this marker across all individuals.
public struct Locus: Codable, Hashable, Sendable, Identifiable {
    /// Unique identifier for this locus.
    public var id: UUID

    /// The name or identifier of the locus (e.g., "MP20", "SNP_12345").
    public var name: String

    /// Physical location of the locus measured in base count along the contig.
    public var location: UInt

    /// The contig or chromosome this locus belongs to (e.g. "1", "dDocent_Contig_16").
    ///
    /// Kept as a plain `String` rather than a numeric type: real contig identifiers
    /// (assembly scaffold names, RAD-tag contigs) are researcher-assigned labels, not
    /// necessarily small integers, and must round-trip exactly.
    public var contig: String

    /// Where this locus's allele labels came from.
    public enum AlleleProvenance: String, Codable, Sendable {
        /// Allele labels came from the source data itself: microsatellite allele
        /// sizes, or real REF/ALT bases read from a VCF.
        case observed
        /// Allele labels are placeholder `Z` (REF-slot) / `z` (ALT-slot) symbols,
        /// assigned because the import source was allele-anonymous (e.g. vcftools
        /// `--012`, which reports only genotype dosage, never REF/ALT bases). This
        /// is REF/ALT identity, **not** major/minor — the reference allele is not
        /// guaranteed to be the more frequent one.
        case refAltPlaceholder
    }

    /// Whether `name`'s allele labels (via this locus's codebook) are real observed
    /// alleles or `Z`/`z` REF/ALT placeholders. Defaults to `.observed`.
    public var alleleProvenance: AlleleProvenance

    /// Initializes a new locus with the specified name and optional location information.
    ///
    /// - Parameters:
    ///   - name: The name or identifier for this locus.
    ///   - location: Physical location in base count (defaults to 0).
    ///   - contig: Contig or chromosome identifier (defaults to `""`).
    ///   - alleleProvenance: Where this locus's allele labels came from (defaults to `.observed`).
    public init(name: String, location: UInt = 0, contig: String = "", alleleProvenance: AlleleProvenance = .observed) {
        self.id = UUID()
        self.name = name
        self.location = location
        self.contig = contig
        self.alleleProvenance = alleleProvenance
    }
}


extension Locus: Comparable {

    /// Compares two loci for sorting purposes.
    ///
    /// Loci are sorted first by contig (natural/numeric-aware order, since contig
    /// names like "dDocent_Contig_16" don't sort correctly lexicographically), then
    /// by physical location on the contig.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand locus.
    ///   - rhs: The right-hand locus.
    /// - Returns: `true` if `lhs` should be ordered before `rhs`.
    public static func < (lhs: Locus, rhs: Locus) -> Bool {
        if lhs.contig != rhs.contig {
            return lhs.contig.naturalCompare(rhs.contig) == .orderedAscending
        } else {
            return lhs.location < rhs.location}
    }

}

extension Locus: Equatable {

    /// Determines if two loci are the same based on their unique identifiers.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand locus.
    ///   - rhs: The right-hand locus.
    /// - Returns: `true` if both loci have the same UUID.
    public static func == (lhs: Locus, rhs: Locus) -> Bool {
        return lhs.id == rhs.id
    }
}
