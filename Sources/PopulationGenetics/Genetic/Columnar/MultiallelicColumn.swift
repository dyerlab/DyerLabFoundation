//
//  MultiallelicColumn.swift
//  PopulationGenetics
//
//  Columnar core: a multiallelic (microsatellite) column storing two parallel
//  UInt8 allele-index arrays. Index 0 is the NULL allele: both zero = missing,
//  one zero = haploid. Allele pairs are returned in canonical (sorted) order.
//

import Foundation

/// A column of multiallelic genotypes as `UInt8` allele-index pairs.
public struct MultiallelicColumn: GenotypeColumn {

    /// Per-locus allele codebook mapping `UInt8` indices to labels.
    public let codebook: AlleleCodebook

    /// The marker type for this column (always `.microsatellite`).
    public var markerType: MarkerType { .microsatellite }

    /// Left allele index per individual (0 = absent).
    private var leftAlleles: [UInt8]

    /// Right allele index per individual (0 = absent).
    private var rightAlleles: [UInt8]

    /// Number of individuals in this column.
    public var count: Int { leftAlleles.count }

    /// Exposes the underlying left-allele bytes (e.g. for serialization).
    public var leftAlleleBytes: [UInt8] { leftAlleles }

    /// Exposes the underlying right-allele bytes (e.g. for serialization).
    public var rightAlleleBytes: [UInt8] { rightAlleles }

    /// Creates a column from parallel left/right allele-index arrays.
    ///
    /// - Parameters:
    ///   - codebook: Per-locus allele codebook.
    ///   - left: Left allele index per individual (0 = absent); must equal `right.count`.
    ///   - right: Right allele index per individual (0 = absent).
    public init(codebook: AlleleCodebook, left: [UInt8], right: [UInt8]) {
        precondition(left.count == right.count, "left and right must be the same length")
        self.codebook = codebook
        self.leftAlleles = left
        self.rightAlleles = right
    }

    /// Creates an all-missing column for `capacity` individuals.
    ///
    /// - Parameters:
    ///   - codebook: Per-locus allele codebook.
    ///   - capacity: Number of individuals; all genotypes initialise to missing (0, 0).
    public init(codebook: AlleleCodebook, capacity: Int) {
        self.codebook = codebook
        self.leftAlleles = [UInt8](repeating: 0, count: capacity)
        self.rightAlleles = [UInt8](repeating: 0, count: capacity)
    }

    /// Sets the genotype at `ordinal` from two allele indices.
    ///
    /// - Parameters:
    ///   - ordinal: Individual row index (0..<count).
    ///   - left: Left allele index (0 = absent).
    ///   - right: Right allele index (0 = absent).
    public mutating func set(at ordinal: Int, left: UInt8, right: UInt8) {
        leftAlleles[ordinal] = left
        rightAlleles[ordinal] = right
    }

    // MARK: GenotypeColumn

    /// Returns `true` when both allele indices at `ordinal` are 0 (missing).
    public func isEmpty(at ordinal: Int) -> Bool {
        leftAlleles[ordinal] == 0 && rightAlleles[ordinal] == 0
    }

    /// Returns the allele-index pair at `ordinal` in canonical (sorted) order, or `nil` if missing.
    public func alleles(at ordinal: Int) -> (UInt8, UInt8)? {
        if isEmpty(at: ordinal) { return nil }
        let l = leftAlleles[ordinal]
        let r = rightAlleles[ordinal]
        return l <= r ? (l, r) : (r, l)
    }
}
