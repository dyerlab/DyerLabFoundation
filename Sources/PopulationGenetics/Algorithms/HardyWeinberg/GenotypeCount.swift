//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeCount.swift
//  PopulationGenetics
//
//  One row of gstudio's genotype_frequencies(): a genotype with its observed
//  count and its count expected under Hardy–Weinberg proportions.
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// A genotype's observed and Hardy–Weinberg expected counts.
public struct GenotypeCount: Sendable, Hashable, Identifiable {

    /// The genotype, `a:b` with the alleles in label order.
    public let genotype: String

    /// How many individuals carry it.
    public let observed: Int

    /// How many are expected under Hardy–Weinberg proportions: `N p²` for a homozygote, `2N pq` for a heterozygote.
    public let expected: Double

    /// The genotype.
    public var id: String { genotype }

    /// Creates a count.
    ///
    /// - Parameters:
    ///   - genotype: The genotype, `a:b`.
    ///   - observed: The individuals carrying it.
    ///   - expected: The count expected under Hardy–Weinberg proportions.
    public init(genotype: String, observed: Int, expected: Double) {
        self.genotype = genotype
        self.observed = observed
        self.expected = expected
    }
}
