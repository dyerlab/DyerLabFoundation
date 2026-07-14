//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  paternalGamete.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 6/28/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

/// Recovers the paternal gamete from an offspring and its mother.
///
/// Both genotypes must be complete diploids (no `0` allele), otherwise the
/// result is `.missing`. An offspring allele is a candidate paternal allele
/// when the *other* offspring allele could have come from the mother.
///
/// - Returns: `.resolved` for one candidate, `.ambiguous` for two,
///   `.impossible` when the offspring cannot descend from the mother.
public func paternalGamete(offspring: (UInt8, UInt8), mother: (UInt8, UInt8)) -> PaternalContribution {
    let (o0, o1) = offspring
    let (m0, m1) = mother

    guard o0 != 0, o1 != 0, m0 != 0, m1 != 0 else { return .missing }

    func inMother(_ allele: UInt8) -> Bool { allele == m0 || allele == m1 }

    var candidates: [UInt8] = []
    if inMother(o1) { candidates.append(o0) }
    if inMother(o0) { candidates.append(o1) }

    let unique = Array(Set(candidates)).sorted()

    switch unique.count {
    case 0:  return .impossible
    case 1:  return .resolved(unique[0])
    default: return .ambiguous(unique[0], unique[1])
    }
}

/// Recovers the paternal gamete for an offspring/mother pair held in a genotype column.
///
/// - Parameters:
///   - offspringOrdinal: Row index of the offspring in `column`.
///   - motherOrdinal: Row index of the mother in `column`.
///   - column: The genotype column providing both genotypes.
/// - Returns: The paternal contribution (`.resolved`, `.ambiguous`, `.impossible`, or `.missing`).
public func paternalGamete(offspringOrdinal: Int, motherOrdinal: Int, in column: GenotypeColumn) -> PaternalContribution {
    guard let offspring = column.alleles(at: offspringOrdinal),
          let mother = column.alleles(at: motherOrdinal) else {
        return .missing
    }
    return paternalGamete(offspring: offspring, mother: mother)
}
