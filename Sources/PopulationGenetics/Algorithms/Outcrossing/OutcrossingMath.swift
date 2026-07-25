//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  OutcrossingMath.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 7/23/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

import Foundation

extension Outcrossing {

    /// Probability of offspring genotype given maternal genotype under selfing.
    ///
    /// This is a *single-locus* probability. The mixture with outcrossing —
    /// `P(offspring | mother) = (1-t) * P(selfing) + t * P(outcrossing)` — must
    /// happen at the *multilocus* level, after taking the product of this
    /// function across every locus in the offspring's genotype: the mating
    /// event (selfed vs. outcrossed) is shared by all loci in one individual,
    /// not chosen independently per locus. Mixing per locus and then taking
    /// the product across loci is a different (incorrect) model — it would
    /// decorrelate homozygosity across loci, destroying the very correlation
    /// multilocus outcrossing-rate estimators depend on. See
    /// the mixture is actually taken.
    ///
    /// - Note: Missing offspring data at this locus is not this function's
    ///   concern — callers skip missing loci entirely (probability 1.0,
    ///   i.e. no contribution to the log-likelihood) before reaching here,
    ///   using ``GenotypeColumn/alleles(at:)``'s `nil` case.
    ///
    /// - Parameters:
    ///   - offspring: Offspring genotype (allele-index pair; `0` denotes missing/null).
    ///   - mother: Maternal genotype (allele-index pair).
    ///   - hasNullModel: Whether the locus is modeled with a null allele at index `0`.
    /// - Returns: The probability of the offspring genotype arising by selfing.
    public static func probabilityOfOffspringGivenSelfing(
        _ offspring: (UInt8, UInt8),
        givenMother mother: (UInt8, UInt8),
        hasNullModel: Bool
    ) -> Double {
        let (s1, s2) = offspring
        let (m1, m2) = mother

        // Sorted indices for easier comparison.
        let sf = min(s1, s2)
        let ss = max(s1, s2)
        let mf = min(m1, m2)
        let ms = max(m1, m2)

        let isOffspringHom = (sf == ss)
        let isMomHom = (mf == ms)

        if hasNullModel {
            if isMomHom {
                if mf == 0 { return 0.0 } // Mom is 0/0
                if isOffspringHom && sf == mf { return 1.0 }
                return 0.0
            } else {
                if mf == 0 { // Mom is het with null allele (0/ms): selfing always transmits ms as the visible allele.
                    if isOffspringHom && sf == ms { return 1.0 }
                    return 0.0
                } else { // Mom is het without null allele (mf/ms)
                    if sf == mf && ss == mf { return 0.25 }
                    if sf == ms && ss == ms { return 0.25 }
                    if sf == mf && ss == ms { return 0.5 }
                    return 0.0
                }
            }
        } else {
            // Standard model
            if isMomHom {
                if isOffspringHom && sf == mf { return 1.0 }
                return 0.0
            } else {
                if sf == mf && ss == mf { return 0.25 }
                if sf == ms && ss == ms { return 0.25 }
                if sf == mf && ss == ms { return 0.5 }
                return 0.0
            }
        }
    }

    /// Probability of offspring genotype given maternal genotype under outcrossing.
    ///
    /// Single-locus, like ``probabilityOfOffspringGivenSelfing(_:givenMother:hasNullModel:)``.
    ///
    /// - Parameters:
    ///   - offspring: Offspring genotype (allele-index pair; `0` denotes missing/null).
    ///   - mother: Maternal genotype (allele-index pair).
    ///   - frequencies: Population allele frequencies at this locus, indexed to match the codebook (index `0` is the null-allele frequency).
    ///   - hasNullModel: Whether the locus is modeled with a null allele at index `0`.
    /// - Returns: The probability of the offspring genotype arising by outcrossing.
    public static func probabilityOfOffspringGivenOutcrossing(
        _ offspring: (UInt8, UInt8),
        givenMother mother: (UInt8, UInt8),
        frequencies: [Double],
        hasNullModel: Bool
    ) -> Double {
        let (s1, s2) = offspring
        let (m1, m2) = mother

        let sf = min(s1, s2)
        let ss = max(s1, s2)
        let mf = min(m1, m2)
        let ms = max(m1, m2)

        let isOffspringHom = (sf == ss)
        let isMomHom = (mf == ms)

        if hasNullModel {
            let pNull = frequencies[0]
            if isMomHom {
                if mf == 0 { // Mom is 0/0
                    if isOffspringHom { return frequencies[Int(sf)] / (1.0 - pNull) }
                    return 0.0
                } else { // Mom is mf/mf
                    if isOffspringHom {
                        if sf == mf { return frequencies[Int(sf)] + pNull }
                        return 0.0
                    } else {
                        if sf == mf { return frequencies[Int(ss)] }
                        if ss == mf { return frequencies[Int(sf)] }
                        return 0.0
                    }
                }
            } else {
                // Mom is heterozygote ms/mf (or ms/0 if mf=0)
                if mf == 0 { // Mom is ms/0: one null allele, one observed allele ms.
                    if isOffspringHom {
                        let pS = frequencies[Int(sf)]
                        if sf == ms {
                            // Apparent homozygote ms/ms is reachable two ways: mom
                            // transmits her invisible null and pollen supplies ms
                            // (renormalized over non-null pollen), or mom transmits
                            // ms and pollen supplies ms or the population's null.
                            return 0.5 * (pS / (1.0 - pNull)) + 0.5 * (pS + pNull)
                        } else {
                            // An apparent homozygote for any other allele can only
                            // arise via mom's invisible null plus a matching pollen allele.
                            return 0.5 * (pS / (1.0 - pNull))
                        }
                    } else {
                        if sf == ms { return 0.5 * frequencies[Int(ss)] }
                        if ss == ms { return 0.5 * frequencies[Int(sf)] }
                        return 0.0
                    }
                } else { // Mom is ms/mf, neither allele is null, but the locus still models null alleles.
                    if isOffspringHom {
                        // Pollen may supply the matching allele directly, or the
                        // invisible null (indistinguishable from a true homozygote).
                        if sf == mf || sf == ms { return 0.5 * (frequencies[Int(sf)] + pNull) }
                        return 0.0
                    }
                    // A visibly heterozygous offspring carries no ambiguity from the
                    // null allele, so this matches the standard-model computation.
                    let p1 = frequencies[Int(sf)]
                    let p2 = frequencies[Int(ss)]
                    let s1InMom = (sf == mf || sf == ms)
                    let s2InMom = (ss == mf || ss == ms)

                    if s1InMom && s2InMom {
                        return 0.5 * (p1 + p2)
                    } else if s1InMom {
                        return 0.5 * p2
                    } else if s2InMom {
                        return 0.5 * p1
                    } else {
                        return 0.0
                    }
                }
            }
        } else {
            // Standard model
            if isMomHom {
                if sf == mf { return frequencies[Int(ss)] }
                if ss == mf { return frequencies[Int(sf)] }
                return 0.0
            } else {
                let p1 = frequencies[Int(sf)]
                let p2 = frequencies[Int(ss)]
                let s1InMom = (sf == mf || sf == ms)
                let s2InMom = (ss == mf || ss == ms)

                if s1InMom && s2InMom {
                    if isOffspringHom { return 0.5 * p1 }
                    return 0.5 * (p1 + p2)
                } else if s1InMom {
                    return 0.5 * p2
                } else if s2InMom {
                    return 0.5 * p1
                } else {
                    return 0.0
                }
            }
        }
    }

    /// Probability of a maternal genotype given population allele frequencies and inbreeding coefficient.
    ///
    /// `P(Gm | F) = (1-F) * P(Gm | HWE) + F * P(Gm | Selfing-Equilibrium)`
    /// `P(Gm=AiAi | F) = p_i^2 (1-F) + p_i F`
    /// `P(Gm=AiAj | F) = 2 p_i p_j (1-F)`
    ///
    /// - Parameters:
    ///   - mother: Maternal genotype (allele-index pair). `(0, 0)` (fully missing) returns `1.0`.
    ///   - frequencies: Population allele frequencies at this locus, indexed to match the codebook.
    ///   - F: The maternal inbreeding coefficient, derived from her inbreeding history (see ``inbreedingCoefficient(forIH:)``).
    /// - Returns: The probability of the maternal genotype.
    public static func probabilityOfMother(
        _ mother: (UInt8, UInt8),
        frequencies: [Double],
        inbreedingCoefficient F: Double
    ) -> Double {
        if mother.0 == 0 && mother.1 == 0 { return 1.0 }

        let (m1, m2) = mother
        let p1 = frequencies[Int(m1)]
        let p2 = frequencies[Int(m2)]

        if m1 == m2 {
            return (p1 * p1 * (1.0 - F)) + (p1 * F)
        } else {
            return 2.0 * p1 * p2 * (1.0 - F)
        }
    }

    /// Converts an inbreeding history category to an inbreeding coefficient.
    ///
    /// `F = 1 - 0.5^IH`, capped at `F = 1.0` once `IH >= 6` (Outcrossing tracks
    /// inbreeding history as 7 discrete categories, `0...6`, the last being
    /// "6 or more consecutive generations of selfing").
    ///
    /// - Parameter ih: The inbreeding history category.
    /// - Returns: The corresponding inbreeding coefficient, in `0...1`.
    public static func inbreedingCoefficient(forIH ih: Int) -> Double {
        ih >= 6 ? 1.0 : 1.0 - pow(0.5, Double(ih))
    }
}

/// Namespace for a Bayesian MCMC estimator of population mean outcrossing
/// rate (t) and inbreeding coefficient (F) from maternal-family genetic
/// marker data, following Ritland's mixed-mating model (the same model
/// implemented by Ritland & Ritland's BORICE, whose sampler this began as a
/// port of — but see below for why this isn't simply named `BORICE`).
///
/// The model: each offspring in a maternal family arose either by selfing
/// (probability `1-t`) or outcrossing (probability `t`); the mother herself
/// carries an inbreeding history reflecting prior generations of selfing.
/// ``Sampler`` draws from the joint posterior over `t`, per-family
/// inbreeding histories, population allele frequencies, and (where
/// maternal tissue wasn't sampled or is ambiguous under a null-allele
/// model) maternal genotypes, via Metropolis-Hastings.
///
/// ## Multilocus (t_m) vs. single-locus (t_s)
///
/// ``GenotypeMatrix/runOutcrossing(design:parameters:hasNullModel:)`` mixes
/// selfing/outcrossing once per offspring, over the *product* of every
/// locus's probability — the multilocus outcrossing rate, `t_m`. This is
/// what stock BORICE computes, and the only thing it computes.
///
/// ``GenotypeMatrix/runSingleLocusOutcrossing(design:parameters:hasNullModel:)``
/// instead estimates `t` independently at each locus — what classical
/// mixed-mating analysis (e.g. MLTR) calls `t_s`. Because `t_s` doesn't
/// exploit cross-locus homozygosity correlation, `t_m - t_s > 0` is the
/// standard diagnostic for biparental inbreeding. This package computes
/// both sides of that comparison, which is why this namespace is the more
/// general `Outcrossing` rather than `BORICE`.
///
/// - SeeAlso: ``GenotypeMatrix/runOutcrossing(design:parameters:hasNullModel:)``,
///   ``GenotypeMatrix/runSingleLocusOutcrossing(design:parameters:hasNullModel:)``
public enum Outcrossing {}
