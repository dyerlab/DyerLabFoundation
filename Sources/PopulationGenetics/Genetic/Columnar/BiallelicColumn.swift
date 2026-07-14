//
//  BiallelicColumn.swift
//  PopulationGenetics
//
//  Columnar core: a biallelic SNP column packed two bits per genotype, four
//  genotypes per byte, LSB-first. Codes are relabeled so 0 == missing, which
//  makes a zero-initialized buffer read as "all missing":
//
//      0b00 (0) = missing       0b01 (1) = hom-ref (AA)
//      0b10 (2) = heterozygote  0b11 (3) = hom-alt (BB)
//
//  Allele indices in the codebook: 1 = reference, 2 = alternate.
//

import Foundation

/// A 2-bit packed column for biallelic SNP genotypes.
public struct BiallelicColumn: GenotypeColumn {

    /// Codebook with up to two non-null alleles (index 1 = ref, 2 = alt).
    public let codebook: AlleleCodebook

    /// The marker type for this column (always `.biallelicSNP`).
    public var markerType: MarkerType { .biallelicSNP }

    /// Number of individuals in this column.
    public let count: Int

    /// Packed 2-bit codes, four per byte, LSB-first.
    private var packed: [UInt8]

    /// Creates an all-missing column for `count` individuals.
    ///
    /// - Parameters:
    ///   - codebook: Per-locus allele codebook (at most two non-null alleles).
    ///   - count: Number of individuals.
    public init(codebook: AlleleCodebook, count: Int) {
        precondition(codebook.alleleCount <= 2, "BiallelicColumn allows at most two alleles")
        self.codebook = codebook
        self.count = count
        self.packed = [UInt8](repeating: 0, count: (count + 3) / 4)
    }

    /// Creates a column from explicit per-individual 2-bit codes.
    ///
    /// - Parameters:
    ///   - codebook: Per-locus allele codebook (at most two non-null alleles).
    ///   - codes: One 2-bit code per individual (0 = missing, 1 = AA, 2 = AB, 3 = BB).
    public init(codebook: AlleleCodebook, codes: [UInt8]) {
        precondition(codebook.alleleCount <= 2, "BiallelicColumn allows at most two alleles")
        self.codebook = codebook
        self.count = codes.count
        self.packed = [UInt8](repeating: 0, count: (codes.count + 3) / 4)
        for (i, code) in codes.enumerated() {
            Self.writeCode(&packed, at: i, code & 0b11)
        }
    }

    /// Exposes the underlying packed bytes (e.g. for serialization).
    public var packedBytes: [UInt8] { packed }

    /// Creates a column from pre-packed bytes (e.g. when deserializing).
    ///
    /// - Parameters:
    ///   - codebook: Per-locus allele codebook (at most two non-null alleles).
    ///   - count: Number of individuals.
    ///   - packedBytes: Packed 2-bit codes, four per byte, LSB-first; must have `(count + 3) / 4` bytes.
    public init(codebook: AlleleCodebook, count: Int, packedBytes: [UInt8]) {
        precondition(codebook.alleleCount <= 2, "BiallelicColumn allows at most two alleles")
        precondition(packedBytes.count == (count + 3) / 4, "packedBytes length must match count")
        self.codebook = codebook
        self.count = count
        self.packed = packedBytes
    }

    // MARK: Bit access

    @inline(__always)
    private static func writeCode(_ buffer: inout [UInt8], at ordinal: Int, _ code: UInt8) {
        let byte = ordinal >> 2
        let shift = UInt8((ordinal & 3) << 1)
        buffer[byte] = (buffer[byte] & ~(0b11 << shift)) | ((code & 0b11) << shift)
    }

    /// The raw 2-bit code at `ordinal` (0 missing, 1 AA, 2 AB, 3 BB).
    @inline(__always)
    public func code(at ordinal: Int) -> UInt8 {
        let byte = ordinal >> 2
        let shift = UInt8((ordinal & 3) << 1)
        return (packed[byte] >> shift) & 0b11
    }

    /// Sets the 2-bit code at `ordinal`.
    public mutating func setCode(at ordinal: Int, _ code: UInt8) {
        Self.writeCode(&packed, at: ordinal, code)
    }

    /// Alternate-allele dosage (0, 1, 2) or `nil` if missing.
    public func dosage(at ordinal: Int) -> UInt8? {
        let c = code(at: ordinal)
        return c == 0 ? nil : c - 1
    }

    // MARK: GenotypeColumn

    /// Returns `true` when the genotype at `ordinal` is missing (code == 0).
    public func isEmpty(at ordinal: Int) -> Bool {
        code(at: ordinal) == 0
    }

    /// Returns the two allele indices at `ordinal`, or `nil` if missing.
    ///
    /// - Returns: `(1,1)` for AA, `(1,2)` for AB, `(2,2)` for BB, or `nil` for missing.
    public func alleles(at ordinal: Int) -> (UInt8, UInt8)? {
        switch code(at: ordinal) {
        case 1: return (1, 1)   // hom-ref
        case 2: return (1, 2)   // heterozygote
        case 3: return (2, 2)   // hom-alt
        default: return nil     // missing
        }
    }
}
