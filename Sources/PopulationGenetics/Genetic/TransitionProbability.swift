//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  TransitionProbability.swift
//  PopulationGenetics
//
//  A port of gstudio's transition_probability() (1.15.3): Mendelian
//  probabilities of an offspring genotype given its parents, on allele-index
//  pairs. Three forms, as in R:
//
//  - two parents: the share of the four mother × father allele combinations
//    that give the offspring's genotype;
//  - one parent and a random mate (`freqs =` in R): Σ over the mother's two
//    alleles a of ½ P(the other offspring allele), with the paternal allele
//    drawn from the allele frequencies, so a two-parent value divided by it is
//    the paternity index;
//  - one parent alone: a compatibility score, the probability under a mate
//    with the offspring's own genotype, not a likelihood.
//
//  A missing genotype (either allele 0) gives `nil`, R's NA, and the
//  multilocus value is the product over the loci that have one.
//  Fixture: `Fixtures/generate_transition_fixtures.R`.
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// Mendelian transition probabilities of an offspring genotype from its parents.
public enum TransitionProbability {

    /// A diploid genotype as two allele indices; `0` is the missing allele.
    public typealias Alleles = (UInt8, UInt8)

    /// The probability of the offspring from two parents.
    ///
    /// - Parameters:
    ///   - offspring: The offspring's alleles.
    ///   - mother: The mother's alleles.
    ///   - father: The father's alleles.
    /// - Returns: The share of the four parental allele combinations that give the offspring (0, ¼, ½ or 1), or
    ///   `nil` if any genotype is missing.
    public static func twoParent(offspring: Alleles, mother: Alleles, father: Alleles) -> Double? {
        guard complete(offspring), complete(mother), complete(father) else { return nil }
        var matches = 0
        for m in [mother.0, mother.1] {
            for d in [father.0, father.1] where same((m, d), offspring) { matches += 1 }
        }
        return Double(matches) / 4
    }

    /// The probability of the offspring from its mother and a random mate.
    ///
    /// - Parameters:
    ///   - offspring: The offspring's alleles.
    ///   - mother: The mother's alleles.
    ///   - frequencies: The allele frequencies of the mates, indexed by allele index (slot 0 unused), as
    ///     `TwoGenerAnalysis.pollenPool` holds them; an index past the end has frequency 0.
    /// - Returns: `Σₐ ½ p(the offspring's other allele)` over the mother's alleles `a` that the offspring carries,
    ///   or `nil` if either genotype is missing.
    public static func randomMate(offspring: Alleles, mother: Alleles, frequencies: [Double]) -> Double? {
        guard complete(offspring), complete(mother) else { return nil }
        func p(_ allele: UInt8) -> Double { Int(allele) < frequencies.count ? frequencies[Int(allele)] : 0 }
        var total = 0.0
        for a in [mother.0, mother.1] {
            if a == offspring.0 { total += p(offspring.1) / 2 }
            else if a == offspring.1 { total += p(offspring.0) / 2 }
        }
        return total
    }

    /// gstudio's one-parent compatibility score: the probability under a mate with the offspring's own genotype.
    ///
    /// - Parameters:
    ///   - offspring: The offspring's alleles.
    ///   - mother: The mother's alleles.
    /// - Returns: `(½ if the mother is heterozygous) × (½ if the offspring is) × (alleles they share)`, or `nil`
    ///   if either genotype is missing.
    public static func compatibility(offspring: Alleles, mother: Alleles) -> Double? {
        guard complete(offspring), complete(mother) else { return nil }
        var score = mother.0 != mother.1 ? 0.5 : 1.0
        if offspring.0 != offspring.1 { score /= 2 }
        return score * Double(Set([mother.0, mother.1]).intersection([offspring.0, offspring.1]).count)
    }

    /// The multilocus probability: the product over the loci where it is defined.
    ///
    /// - Parameters:
    ///   - matrix: The genotypes.
    ///   - offspring: The offspring's row.
    ///   - mother: The mother's row.
    ///   - father: The father's row, or `nil` for one parent.
    ///   - frequencies: With no father, the mates' allele frequencies per locus (indexed by allele index), for the
    ///     random-mate form; `nil` for the compatibility score.
    /// - Returns: The product over loci with all genotypes present (`1` if there are none).
    public static func multilocus(matrix: GenotypeMatrix, offspring: Int, mother: Int, father: Int? = nil,
                                  frequencies: [[Double]]? = nil) -> Double {
        matrix.columns.indices.reduce(1.0) { product, j in
            let column = matrix.columns[j]
            let missing: Alleles = (0, 0)
            let o = column.alleles(at: offspring) ?? missing, m = column.alleles(at: mother) ?? missing
            let value: Double? = if let father {
                twoParent(offspring: o, mother: m, father: column.alleles(at: father) ?? missing)
            } else if let frequencies {
                randomMate(offspring: o, mother: m, frequencies: j < frequencies.count ? frequencies[j] : [])
            } else {
                compatibility(offspring: o, mother: m)
            }
            return product * (value ?? 1)
        }
    }

    /// Whether both alleles are present.
    private static func complete(_ alleles: Alleles) -> Bool { alleles.0 != 0 && alleles.1 != 0 }

    /// Whether two unordered genotypes are the same.
    private static func same(_ a: Alleles, _ b: Alleles) -> Bool {
        (a.0 == b.0 && a.1 == b.1) || (a.0 == b.1 && a.1 == b.0)
    }
}
