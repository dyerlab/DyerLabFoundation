//
//  AlleleFrequencies.swift
//  PopulationGenetics
//
//  Columnar core: an incremental allele-count accumulator keyed by `UInt8`
//  allele index. Value type so it is cheap to copy for permutation/null-model
//  work and `Sendable` for parallel reduction. Supports symmetric add/remove
//  so individuals can be reconfigured across groupings without a full rebuild.
//

import Foundation

/// Accumulated allele counts and diversity statistics for a set of genotypes
/// at a single locus.
///
/// Counts are indexed by allele index (see `AlleleCodebook`); slot `0` is the
/// NULL allele and is never counted. Build one for "all individuals" or one per
/// stratum, feeding genotypes via `add(left:right:)`; `remove(left:right:)`
/// reverses an addition exactly.
public struct AlleleFrequencies: Sendable {

    /// Allele counts indexed by allele index. `counts[0]` (NULL) stays at 0.
    public private(set) var counts: [Double]

    /// Number of heterozygous genotypes accumulated.
    public private(set) var numHets: Double

    /// Number of (non-empty) genotypes accumulated.
    public private(set) var numGenos: Double

    /// Creates an accumulator with `alleleSlots` count slots (including NULL at index 0).
    ///
    /// - Parameter alleleSlots: Total number of slots; must be ≥ 1.
    public init(alleleSlots: Int) {
        precondition(alleleSlots >= 1, "Need at least the NULL slot")
        self.counts = [Double](repeating: 0.0, count: alleleSlots)
        self.numHets = 0.0
        self.numGenos = 0.0
    }

    /// Creates an accumulator sized to a codebook.
    public init(codebook: AlleleCodebook) {
        self.init(alleleSlots: codebook.count)
    }
}


// MARK: - Incremental accumulation

extension AlleleFrequencies {

    /// Adds one genotype expressed as a pair of allele indices.
    ///
    /// A gamete index of `0` is treated as absent: two zeros is an empty
    /// genotype (ignored), one zero is haploid (one allele counted).
    public mutating func add(left: UInt8, right: UInt8) {
        let lPresent = left != 0
        let rPresent = right != 0
        if !lPresent && !rPresent { return }

        if lPresent && rPresent {
            counts[Int(left)] += 1.0
            counts[Int(right)] += 1.0
            if left != right { numHets += 1.0 }
        } else {
            counts[Int(lPresent ? left : right)] += 1.0
        }
        numGenos += 1.0
    }

    /// Reverses a previous `add(left:right:)` with the same indices.
    public mutating func remove(left: UInt8, right: UInt8) {
        let lPresent = left != 0
        let rPresent = right != 0
        if !lPresent && !rPresent { return }

        if lPresent && rPresent {
            counts[Int(left)] -= 1.0
            counts[Int(right)] -= 1.0
            if left != right { numHets -= 1.0 }
        } else {
            counts[Int(lPresent ? left : right)] -= 1.0
        }
        numGenos -= 1.0
    }
}


// MARK: - Counts and frequencies

extension AlleleFrequencies {

    /// Total number of counted alleles (the frequency denominator).
    public var N: Double { counts.reduce(0.0, +) }

    /// Non-null allele indices actually observed (count > 0).
    public var observedAlleleIndices: [UInt8] {
        (1..<counts.count).filter { counts[$0] > 0.0 }.map { UInt8($0) }
    }

    /// Returns the count for a specific allele index.
    public func count(forIndex index: UInt8) -> Double {
        let i = Int(index)
        return i < counts.count ? counts[i] : 0.0
    }

    /// Returns the frequency of an allele index, or `NaN` when no data exists.
    public func frequency(forIndex index: UInt8) -> Double {
        let n = N
        return n > 0 ? count(forIndex: index) / n : Double.nan
    }

    /// Frequencies for every non-null slot (`1..<count`), or `[]` when empty.
    public func frequencies() -> [Double] {
        let n = N
        guard n > 0 else { return [] }
        return (1..<counts.count).map { counts[$0] / n }
    }
}


// MARK: - Diversity statistics

extension AlleleFrequencies {

    /// Allelic richness: number of distinct non-null alleles observed.
    public var A: Double { Double(observedAlleleIndices.count) }

    /// Number of common alleles (frequency ≥ 5%).
    public var A95: Double { Double(frequencies().filter { $0 >= 0.05 }.count) }

    /// Effective number of alleles: `1 / Σ p²`, or 0 when empty.
    public var Ae: Double {
        let sumSq = frequencies().map { $0 * $0 }.reduce(0.0, +)
        return sumSq > 0.0 ? 1.0 / sumSq : 0.0
    }

    /// Observed heterozygosity: heterozygotes / genotypes, or `NaN` when empty.
    public var Ho: Double { numGenos > 0 ? numHets / numGenos : Double.nan }

    /// Expected heterozygosity (Nei's gene diversity): `1 - Σ p²`.
    public var He: Double {
        1.0 - frequencies().map { $0 * $0 }.reduce(0.0, +)
    }
}


// MARK: - Markdown rendering

extension AlleleFrequencies {

    /// Renders the frequencies as a single Markdown table row.
    ///
    /// - Parameters:
    ///   - codebook: The codebook used to order/label alleles.
    ///   - indices: Optional explicit allele indices; defaults to all non-null.
    public func asMarkdownTableRow(codebook: AlleleCodebook, indices: [UInt8]? = nil) -> String {
        let idx = indices ?? codebook.alleleIndices
        let cells = idx.map { String(format: "%.4f", frequency(forIndex: $0)) }
        return "| " + cells.joined(separator: " | ") + " |"
    }

    /// Renders a complete Markdown table (header + separator + frequency row).
    public func asMarkdownTable(codebook: AlleleCodebook) -> String {
        let idx = codebook.alleleIndices
        let header = "| " + idx.map { codebook.label(for: $0) }.joined(separator: " | ") + " |"
        let sep = "| " + idx.map { _ in "---" }.joined(separator: " | ") + " |"
        return [header, sep, asMarkdownTableRow(codebook: codebook, indices: idx)].joined(separator: "\n")
    }
}
