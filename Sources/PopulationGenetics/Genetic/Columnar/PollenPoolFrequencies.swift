//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PollenPoolFrequencies.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 6/28/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

/// Accumulates recovered paternal gametes into a pollen-pool allele-frequency
/// distribution, keyed by `UInt8` allele index.
///
/// Resolved gametes contribute a whole count; ambiguous gametes split half a
/// count to each candidate. Impossible and missing pairs are tallied but
/// excluded from the frequencies.
public struct PollenPoolFrequencies: Sendable {

    /// Paternal-gamete counts indexed by allele index (fractional for ambiguous).
    public private(set) var counts: [Double]

    /// Number of unambiguously resolved gametes.
    public private(set) var nResolved: Double
    /// Number of ambiguous gametes (split fractionally).
    public private(set) var nAmbiguous: Double
    /// Number of mother/offspring pairs incompatible with maternity.
    public private(set) var nImpossible: Double
    /// Number of pairs skipped for incomplete genotypes.
    public private(set) var nMissing: Double

    /// Creates an empty accumulator with `alleleSlots` count slots (including NULL at index 0).
    ///
    /// - Parameter alleleSlots: Total number of allele slots; must be ≥ 1.
    public init(alleleSlots: Int) {
        precondition(alleleSlots >= 1, "Need at least the NULL slot")
        self.counts = [Double](repeating: 0.0, count: alleleSlots)
        self.nResolved = 0.0
        self.nAmbiguous = 0.0
        self.nImpossible = 0.0
        self.nMissing = 0.0
    }

    /// Creates an empty accumulator sized to a codebook.
    ///
    /// - Parameter codebook: The codebook for this locus; determines the number of allele slots.
    public init(codebook: AlleleCodebook) {
        self.init(alleleSlots: codebook.count)
    }

    /// Adds a single recovered paternal contribution.
    public mutating func add(_ contribution: PaternalContribution) {
        switch contribution {
        case .resolved(let allele):
            counts[Int(allele)] += 1.0
            nResolved += 1.0
        case .ambiguous(let a, let b):
            counts[Int(a)] += 0.5
            counts[Int(b)] += 0.5
            nAmbiguous += 1.0
        case .impossible:
            nImpossible += 1.0
        case .missing:
            nMissing += 1.0
        }
    }

    /// Recovers and adds the paternal gamete for an offspring/mother genotype pair.
    public mutating func add(offspring: (UInt8, UInt8), mother: (UInt8, UInt8)) {
        add(paternalGamete(offspring: offspring, mother: mother))
    }
}


// MARK: - Pollen-pool frequencies and diversity

extension PollenPoolFrequencies {

    /// Total paternal-gamete count contributing to frequencies (resolved + ambiguous).
    public var N: Double { counts.reduce(0.0, +) }

    /// Returns the count for a paternal allele index.
    public func count(forIndex index: UInt8) -> Double {
        let i = Int(index)
        return i < counts.count ? counts[i] : 0.0
    }

    /// Returns the pollen-pool frequency for an allele index, or `NaN` if empty.
    public func frequency(forIndex index: UInt8) -> Double {
        let n = N
        return n > 0 ? count(forIndex: index) / n : Double.nan
    }

    /// Pollen-pool frequencies for all non-null slots, or `[]` when empty.
    public func frequencies() -> [Double] {
        let n = N
        guard n > 0 else { return [] }
        return (1..<counts.count).map { counts[$0] / n }
    }

    /// Expected heterozygosity of the pollen pool: `1 - Σ p²`.
    public var He: Double {
        1.0 - frequencies().map { $0 * $0 }.reduce(0.0, +)
    }

    /// Effective number of pollen-pool alleles: `1 / Σ p²`, or 0 when empty.
    public var Ae: Double {
        let sumSq = frequencies().map { $0 * $0 }.reduce(0.0, +)
        return sumSq > 0.0 ? 1.0 / sumSq : 0.0
    }
}
