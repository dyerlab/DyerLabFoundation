//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ImportedDataset+Families.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.01.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension ImportedDataset {

    /// The families with both a genotyped mother and at least one offspring;
    /// a mother sampled alone is an adult, not a family to inspect.
    public var familiesWithOffspring: [MaternalFamily] {
        parentage.families.filter { $0.mother != nil && !$0.offspring.isEmpty }
    }

    /// The rows of the adults: every individual, or only the mothers
    /// (Offspring `0`) in parent/offspring data.
    public var adultOrdinals: [Int] {
        parentage.families.isEmpty ? Array(0..<matrix.individualCount) : parentage.adultOrdinals.sorted()
    }

    /// The paternal gamete of an offspring at a locus, found by removing its mother's contribution.
    ///
    /// - Parameters:
    ///   - offspring: The offspring's row in `matrix`.
    ///   - mother: The mother's row in `matrix`.
    ///   - locus: The locus's index in `matrix`.
    /// - Returns: The paternal allele, both alleles when the offspring shares the
    ///   mother's heterozygote, `.impossible` when it shares no allele with her,
    ///   or `.missing` when either genotype is missing.
    public func paternalContribution(offspring: Int, mother: Int, locus: Int) -> PaternalContribution {
        paternalGamete(offspringOrdinal: offspring, motherOrdinal: mother, in: matrix.columns[locus])
    }

    /// The paternal gamete of an offspring at a locus as text: the paternal
    /// allele's label, or the offspring's full genotype when the paternal
    /// allele is ambiguous or impossible.
    ///
    /// - Parameters:
    ///   - offspring: The offspring's row in `matrix`.
    ///   - mother: The mother's row in `matrix`.
    ///   - locus: The locus's index in `matrix`.
    /// - Returns: The text, and the contribution it was made from; `""` for missing data.
    public func paternalText(offspring: Int,
                             mother: Int,
                             locus: Int) -> (text: String, contribution: PaternalContribution) {
        let contribution = paternalContribution(offspring: offspring, mother: mother, locus: locus)
        switch contribution {
        case .resolved(let allele):
            return (matrix.columns[locus].codebook.label(for: allele), contribution)
        case .ambiguous, .impossible:
            let genotype = alleleLabels(at: offspring, locus: locus).map { $0 + ":" + $1 } ?? ""
            return (genotype, contribution)
        case .missing:
            return ("", contribution)
        }
    }
}
