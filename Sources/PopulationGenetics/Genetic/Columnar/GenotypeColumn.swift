//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeColumn.swift
//  PopulationGenetics
//
//  Columnar core: the locus-major storage abstraction. One column holds every
//  individual's genotype at a single locus, addressed by integer ordinal. The
//  concrete backing (2-bit SNP dosage vs. UInt8 microsat index pairs) is hidden
//  behind this protocol; algorithms reduce a column over a set of row ordinals.
//
//  Created by Rodney Dyer on 2026.07.14.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// A locus-major column of genotypes addressed by individual ordinal.
///
/// A statistic is "reduce this column over a set of individual ordinals" — the
/// same call serves all individuals, any stratum, or a permuted null partition.
public protocol GenotypeColumn: Sendable {

    /// Number of individuals (valid ordinals are `0..<count`).
    var count: Int { get }

    /// The allele codebook translating indices to labels for this locus.
    var codebook: AlleleCodebook { get }

    /// The marker type backing this column.
    var markerType: MarkerType { get }

    /// Whether the genotype at `ordinal` is entirely missing.
    ///
    /// - Parameter ordinal: The individual ordinal.
    func isEmpty(at ordinal: Int) -> Bool

    /// The genotype at `ordinal` as a pair of allele indices, or `nil` if
    /// missing. A returned `0` in one position denotes a haploid/absent gamete.
    func alleles(at ordinal: Int) -> (UInt8, UInt8)?
}

// MARK: - Shared reductions

public extension GenotypeColumn {

    /// Whether the genotype at `ordinal` is a (diploid) heterozygote.
    ///
    /// - Parameter ordinal: The individual ordinal.
    /// - Returns: `true` for a complete genotype with two different alleles.
    func isHeterozygote(at ordinal: Int) -> Bool {
        guard let (l, r) = alleles(at: ordinal) else { return false }
        return l != 0 && r != 0 && l != r
    }

    /// Accumulates allele frequencies over a subset of individual ordinals.
    ///
    /// - Parameter rows: The individual ordinals to include.
    /// - Returns: The accumulated frequencies.
    func frequencies<Rows: Sequence>(over rows: Rows) -> AlleleFrequencies
    where Rows.Element == Int {
        var freqs = AlleleFrequencies(codebook: codebook)
        for i in rows {
            if let (l, r) = alleles(at: i) {
                freqs.add(left: l, right: r)
            }
        }
        return freqs
    }

    /// Accumulates allele frequencies over all individuals in the column.
    ///
    /// - Returns: The accumulated frequencies.
    func frequencies() -> AlleleFrequencies {
        frequencies(over: 0..<count)
    }
}
