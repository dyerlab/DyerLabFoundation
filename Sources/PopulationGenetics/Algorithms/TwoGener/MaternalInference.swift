//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MaternalInference.swift
//  PopulationGenetics
//
//  A missing maternal genotype reconstructed from her offspring by maximum
//  likelihood, as gstudio's PhiFT does (`.infer_maternal()`, 1.15.5). For a
//  candidate mother a:b the likelihood of her offspring is
//
//      Πₒ ½ [P(o | a transmitted) + P(o | b transmitted)],
//
//  with the paternal allele drawn from the allele frequencies at the locus
//  (mothers and offspring of families with a mother, pooled). The best
//  genotype is used when it is at least 20 times as likely as the next best;
//  otherwise the mother stays missing. Candidates are every pair of alleles
//  seen at the locus, in label order, and ties keep that order, as R's stable
//  `order()` does. Fixture: `Fixtures/generate_maternal_inference_fixtures.R`.
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix

/// A maternal genotype missing at one locus, and what her offspring say it was.
///
/// ``TwoGenerAnalysis`` reconstructs one for every mother missing at a locus who has offspring there, and uses
/// ``genotype`` (marked ``Genotype/isEstimated``) to recover their paternal gametes when ``isUsed``.
public struct MaternalInference: Sendable {

    /// The smallest likelihood ratio, best over next best, at which a reconstruction is used.
    public static let minimumLikelihoodRatio = 20.0

    /// The maternal family's identifier.
    public let family: String

    /// The mother's name.
    public let mother: String

    /// The locus's name.
    public let locus: String

    /// The offspring genotyped at the locus, which the reconstruction rests on.
    public let offspringCount: Int

    /// The most likely maternal genotype, marked as estimated, or `nil` when no offspring are genotyped at the
    /// locus or no single genotype is compatible with all of them.
    public let genotype: Genotype?

    /// The next most likely genotype, if there is one.
    public let alternative: Genotype?

    /// How many times as likely ``genotype`` is as ``alternative``: `.infinity` when it is the only compatible
    /// genotype, `nil` when there is no ``genotype``.
    public let likelihoodRatio: Double?

    /// Whether ``genotype`` was used, i.e. ``likelihoodRatio`` is at least ``minimumLikelihoodRatio``.
    public var isUsed: Bool { (likelihoodRatio ?? 0) >= Self.minimumLikelihoodRatio }

    /// The mother's row in the genotype matrix.
    let motherOrdinal: Int

    /// The locus's ordinal.
    let locusOrdinal: Int

    /// ``genotype``'s allele indices, in label order.
    let alleles: (UInt8, UInt8)?

    /// A sentence for the analysis notes saying what was inferred, or why not.
    public var message: String {
        let at = "Mother \(mother) (family \(family)) at \(locus)"
        guard let genotype else {
            return offspringCount == 0
                ? "\(at) is not genotyped and none of her offspring are, so her offspring's paternal alleles there "
                    + "were imputed from the pollen-pool frequencies."
                : "\(at) is not genotyped and her \(offspringCount) offspring there are compatible with no single "
                    + "maternal genotype (check for mistyping), so their paternal alleles there were imputed from "
                    + "the pollen-pool frequencies."
        }
        let support = likelihoodRatio == .infinity
            ? "the only genotype compatible with them"
            : "\(Self.format(likelihoodRatio ?? .nan)) times as likely as \(alternative?.description ?? "any other")"
        return isUsed
            ? "\(at) is not genotyped; \(genotype) was inferred from \(offspringCount) offspring (\(support)) and "
                + "used to recover their paternal gametes."
            : "\(at) is not genotyped; the best reconstruction from \(offspringCount) offspring, \(genotype), is "
                + "only \(support), short of \(Self.format(Self.minimumLikelihoodRatio)), so her offspring's "
                + "paternal alleles there were imputed from the pollen-pool frequencies."
    }

    /// Reconstructs every missing maternal genotype that has offspring to go on.
    ///
    /// - Parameters:
    ///   - matrix: Genotypes of mothers and offspring.
    ///   - design: The maternal families; families without a mother are ignored.
    ///   - loci: The locus ordinals to consider.
    /// - Returns: One inference per mother and locus where she is missing and has offspring, in locus order and
    ///   then family order.
    static func infer(matrix: GenotypeMatrix, design: ParentageDesign, loci: [Int]) -> [MaternalInference] {
        let families = design.families.filter { $0.mother != nil && !$0.offspring.isEmpty }
        var result: [MaternalInference] = []
        for j in loci {
            let column = matrix.columns[j]
            let missing = families.filter { complete(column, $0.mother ?? 0) == nil }
            guard !missing.isEmpty else { continue }

            // Allele frequencies over the mothers and offspring of families with a mother.
            var counts = [Double](repeating: 0, count: column.codebook.count)
            for family in design.families {
                guard let mother = family.mother else { continue }
                for ordinal in [mother] + family.offspring {
                    guard let (a, b) = complete(column, ordinal) else { continue }
                    counts[Int(a)] += 1
                    counts[Int(b)] += 1
                }
            }
            let total = counts.reduce(0, +)
            let p = counts.map { total > 0 ? $0 / total : 0 }
            let seen = (1..<counts.count).filter { counts[$0] > 0 }.map { UInt8($0) }
                .sorted { column.codebook.label(for: $0) < column.codebook.label(for: $1) }
            var candidates: [(UInt8, UInt8)] = []
            for (i, a) in seen.enumerated() { for b in seen[i...] { candidates.append((a, b)) } }

            for family in missing {
                let mother = family.mother ?? 0
                let kids = family.offspring.compactMap { complete(column, $0) }
                func transmitted(_ m: UInt8, _ o: (UInt8, UInt8)) -> Double {
                    (o.0 == m ? p[Int(o.1)] : 0) + (o.1 == m ? p[Int(o.0)] : 0)
                        - (o.0 == m && o.1 == m ? p[Int(o.0)] : 0)
                }
                var best: (UInt8, UInt8)?, next: (UInt8, UInt8)?, ratio: Double?
                if !kids.isEmpty, !candidates.isEmpty {
                    let scored = candidates.map { g in
                        (g, kids.reduce(0.0) { $0 + log(0.5 * (transmitted(g.0, $1) + transmitted(g.1, $1))) })
                    }
                    // A stable sort, best first, so ties keep label order.
                    let ordered = scored.enumerated().sorted {
                        $0.element.1 != $1.element.1 ? $0.element.1 > $1.element.1 : $0.offset < $1.offset
                    }.map(\.element)
                    let top = ordered[0]
                    if ordered.count > 1 { next = ordered[1].0 }
                    if top.1.isFinite {
                        best = top.0
                        ratio = ordered.count > 1 ? exp(top.1 - ordered[1].1) : .infinity
                    }
                }
                func genotype(_ g: (UInt8, UInt8)?, estimated: Bool) -> Genotype? {
                    g.map { Genotype(leftAllele: column.codebook.label(for: $0.0),
                                     rightAllele: column.codebook.label(for: $0.1), isEstimated: estimated) }
                }
                result.append(MaternalInference(
                    family: family.id, mother: matrix.individuals[mother].name, locus: matrix.loci[j].name,
                    offspringCount: kids.count, genotype: genotype(best, estimated: true),
                    alternative: best == nil ? nil : genotype(next, estimated: false), likelihoodRatio: ratio,
                    motherOrdinal: mother, locusOrdinal: j, alleles: best))
            }
        }
        return result
    }

    /// A complete diploid genotype, or `nil` when either allele is missing.
    ///
    /// - Parameters:
    ///   - column: The locus.
    ///   - ordinal: The individual's row.
    /// - Returns: The allele indices.
    private static func complete(_ column: any GenotypeColumn, _ ordinal: Int) -> (UInt8, UInt8)? {
        guard let (a, b) = column.alleles(at: ordinal), a != 0, b != 0 else { return nil }
        return (a, b)
    }

    /// A likelihood ratio to three significant figures, as gstudio prints it.
    ///
    /// - Parameter value: The ratio.
    /// - Returns: The text.
    private static func format(_ value: Double) -> String {
        value.isInfinite ? "Inf" : String(format: "%.3g", value)
    }
}
