//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  CorrelatedPaternity.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 7/24/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

import Foundation

/// Correlated paternity (`r_p`) for a maternal family or population: how
/// much more likely two of a mother's outcrossed offspring are to share a
/// father than two offspring drawn from independent pollen donors would be.
///
/// Estimated by Ritland's (1989) moment estimator: for every pair of
/// siblings, the probability their recovered paternal alleles (see
/// `paternalGamete(offspring:mother:)`) match is modeled as
/// `r_p + (1 - r_p) * S`, where `S = Σ p_k²` is the background match
/// probability implied by the population's pollen-pool allele frequencies
/// (``PollenPoolFrequencies``). `r_p` is the excess match rate over that
/// background, normalized by `1 - S`, combined across sib pairs and loci as
/// a ratio of sums — more polymorphic loci (lower `S`) carry more weight
/// automatically, since a chance match there is more surprising.
///
/// This estimator identifies "same father" with "identical transmitted
/// allele," which is exact only when a shared father is treated as
/// contributing a single allele rather than one of his own two — the usual
/// simplification when father genotypes aren't observed directly.
///
/// - SeeAlso: ``GenotypeMatrix/correlatedPaternity(design:)``,
///   ``GenotypeMatrix/correlatedPaternityPerFamily(design:)``
public struct CorrelatedPaternity: Sendable {

    /// The correlated paternity estimate. Typically in `0...1`, but as an
    /// unbiased moment estimator it can fall slightly outside that range
    /// under sampling noise, especially with few informative pairs.
    public let rp: Double

    /// Number of sib-pair/locus observations informing this estimate (both
    /// individuals had a resolved or ambiguous paternal allele). `0` means
    /// ``rp`` and ``effectiveNumberOfPollenDonors`` carry no information.
    public let informativePairCount: Int

    /// The idealized number of fathers contributing to the pollen pool —
    /// `1 / r_p`. `nil` when ``rp`` is non-positive (no detectable excess
    /// paternity correlation), where "effective number of donors" isn't a
    /// meaningful positive quantity.
    public var effectiveNumberOfPollenDonors: Double? {
        rp > 0 ? 1.0 / rp : nil
    }
}

extension GenotypeMatrix {

    /// Correlated paternity pooled across every family in `design` — a population-level estimate.
    ///
    /// - Parameter design: The maternal families to analyze. A family with no genotyped mother contributes nothing — paternal alleles can't be recovered without her genotype.
    /// - Returns: The pooled correlated-paternity estimate.
    public func correlatedPaternity(design: ParentageDesign) -> CorrelatedPaternity {
        let pollenPools = populationPollenPoolFrequencies(design: design)
        return correlatedPaternity(families: design.families, pollenPools: pollenPools)
    }

    /// Correlated paternity computed separately for each family in `design`.
    ///
    /// The background pollen-pool allele frequencies are still estimated by
    /// pooling every family together (one family's offspring are too few to
    /// reliably estimate population allele frequencies on their own), but
    /// the sib-pair matching behind each ``CorrelatedPaternity/rp`` only
    /// uses that one family's offspring.
    ///
    /// - Parameter design: The maternal families to analyze.
    /// - Returns: One estimate per family, in ``ParentageDesign/families`` order. A family with no genotyped mother gets `informativePairCount == 0`.
    public func correlatedPaternityPerFamily(design: ParentageDesign) -> [CorrelatedPaternity] {
        let pollenPools = populationPollenPoolFrequencies(design: design)
        return design.families.map { correlatedPaternity(families: [$0], pollenPools: pollenPools) }
    }

    /// Population-wide pollen-pool allele frequencies at every locus, pooling every family's recovered paternal alleles.
    private func populationPollenPoolFrequencies(design: ParentageDesign) -> [PollenPoolFrequencies] {
        (0..<locusCount).map { j in
            let column = columns[j]
            var pool = PollenPoolFrequencies(codebook: column.codebook)
            for family in design.families {
                guard let motherOrdinal = family.mother else { continue }
                for offspringOrdinal in family.offspring {
                    pool.add(paternalGamete(offspringOrdinal: offspringOrdinal, motherOrdinal: motherOrdinal, in: column))
                }
            }
            return pool
        }
    }

    /// Ritland's moment estimator: pools sib pairs from `families` against the (separately supplied) population pollen-pool frequencies.
    private func correlatedPaternity(families: [MaternalFamily], pollenPools: [PollenPoolFrequencies]) -> CorrelatedPaternity {
        var numerator = 0.0
        var denominator = 0.0
        var informativePairCount = 0

        for j in 0..<locusCount {
            let pool = pollenPools[j]
            guard pool.N > 0 else { continue } // No recovered pollen alleles at this locus.
            let backgroundMatch = 1.0 - pool.He // Σ p_k², the population pollen pool's self-identity probability.

            let column = columns[j]
            for family in families {
                guard let motherOrdinal = family.mother else { continue }
                let offspring = family.offspring
                guard offspring.count > 1 else { continue }

                for i in 0..<(offspring.count - 1) {
                    let contributionI = paternalGamete(offspringOrdinal: offspring[i], motherOrdinal: motherOrdinal, in: column)
                    for k in (i + 1)..<offspring.count {
                        let contributionK = paternalGamete(offspringOrdinal: offspring[k], motherOrdinal: motherOrdinal, in: column)
                        guard let match = Self.matchProbability(contributionI, contributionK) else { continue }

                        numerator += match - backgroundMatch
                        denominator += 1.0 - backgroundMatch
                        informativePairCount += 1
                    }
                }
            }
        }

        let rp = denominator > 0 ? numerator / denominator : Double.nan
        return CorrelatedPaternity(rp: rp, informativePairCount: informativePairCount)
    }

    /// Probability that two (possibly ambiguous) recovered paternal alleles are identical, treating each ambiguous candidate as equally likely.
    ///
    /// - Returns: `nil` if either contribution is uninformative (`.missing` or `.impossible`).
    static func matchProbability(_ a: PaternalContribution, _ b: PaternalContribution) -> Double? {
        switch (a, b) {
        case (.resolved(let x), .resolved(let y)):
            return x == y ? 1.0 : 0.0
        case (.resolved(let x), .ambiguous(let y1, let y2)), (.ambiguous(let y1, let y2), .resolved(let x)):
            return (x == y1 || x == y2) ? 0.5 : 0.0
        case (.ambiguous(let x1, let x2), .ambiguous(let y1, let y2)):
            let matches = [x1 == y1, x1 == y2, x2 == y1, x2 == y2].filter { $0 }.count
            return Double(matches) / 4.0
        default:
            return nil // .missing or .impossible on either side.
        }
    }
}
