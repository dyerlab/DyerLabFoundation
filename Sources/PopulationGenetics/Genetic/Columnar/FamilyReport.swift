//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  FamilyReport.swift
//  PopulationGenetics
//
//  Removing the mother's contribution from each offspring is a data check as
//  much as an analysis: an offspring sharing no allele with its mother at a
//  locus is a genotyping, scoring or labelling error, so the report lists
//  each one.
//
//  Created by Rodney Dyer on 2026.11.01.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// One maternal family's paternal-allele summary.
public struct FamilyReport: Sendable {

    /// An offspring genotype that can't have come from its mother.
    public struct Mismatch: Identifiable, Equatable, Sendable {
        /// The offspring's row in the matrix.
        public let offspring: Int
        /// The locus's index in the matrix.
        public let locus: Int

        /// The offspring and locus together.
        public var id: [Int] { [offspring, locus] }
    }

    /// The family summarised.
    public let family: MaternalFamily

    /// Offspring genotypes with a single paternal allele.
    public let resolved: Int

    /// Offspring genotypes matching the mother's heterozygote, so either allele could be paternal.
    public let ambiguous: Int

    /// Offspring genotypes that can't be compared because the offspring's or the mother's is missing.
    public let missing: Int

    /// Offspring genotypes incompatible with the mother, in offspring then locus order.
    public let mismatches: [Mismatch]

    /// Summarises a family.
    ///
    /// A family without a genotyped mother has no paternal alleles to recover, so every count is
    /// zero.
    ///
    /// - Parameters:
    ///   - dataset: The genotypes.
    ///   - family: The family to summarise.
    public init(dataset: ImportedDataset, family: MaternalFamily) {
        self.family = family
        var resolved = 0, ambiguous = 0, missing = 0
        var mismatches: [Mismatch] = []
        if let mother = family.mother {
            for offspring in family.offspring {
                for locus in 0..<dataset.matrix.locusCount {
                    switch dataset.paternalContribution(offspring: offspring, mother: mother, locus: locus) {
                    case .resolved: resolved += 1
                    case .ambiguous: ambiguous += 1
                    case .missing: missing += 1
                    case .impossible: mismatches.append(Mismatch(offspring: offspring, locus: locus))
                    }
                }
            }
        }
        self.resolved = resolved
        self.ambiguous = ambiguous
        self.missing = missing
        self.mismatches = mismatches
    }
}
