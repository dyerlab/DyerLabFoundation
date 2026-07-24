//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  BORICEMath.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 7/23/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

import Foundation

extension BORICE {

    /// Transition probability of an offspring genotype given maternal genotype and population allele frequencies.
    ///
    /// This combines selfing and outcrossing components:
    /// `P(Go | Gm) = (1-t) * P(Go | Gm, selfing) + t * P(Go | Gm, outcrossing)`
    ///
    /// - Parameters:
    ///   - offspring: Offspring genotype (left, right indices).
    ///   - mother: Maternal genotype (left, right indices).
    ///   - outcrossingRate: Population outcrossing rate (t).
    ///   - frequencies: Allele frequencies for the locus (including index 0 if null model).
    ///   - hasNullModel: Whether the locus is modeled with null alleles.
    /// - Returns: The probability of the offspring genotype.
    public static func probabilityOfOffspring(
        _ offspring: (UInt8, UInt8),
        givenMother mother: (UInt8, UInt8),
        outcrossingRate t: Double,
        frequencies: [Double],
        hasNullModel: Bool
    ) -> Double {
        // Missing data at this locus for offspring results in probability 1.0 (doesn't affect likelihood).
        if offspring.0 == 0 && offspring.1 == 0 {
            return 1.0
        }

        let probSelfing = probabilityOfOffspringGivenSelfing(offspring, givenMother: mother, hasNullModel: hasNullModel)
        let probOutcrossing = probabilityOfOffspringGivenOutcrossing(offspring, givenMother: mother, frequencies: frequencies, hasNullModel: hasNullModel)

        return (1.0 - t) * probSelfing + t * probOutcrossing
    }

    /// Probability of offspring genotype given maternal genotype under selfing.
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
                if mf == 0 { // Mom is het with null allele (0/ms)
                    // In Python: if sh and (sf == ms): return 1.0. 
                    // This is for a 0/ms mom. Progeny will be 0/0, 0/ms, ms/ms. 
                    // If progeny is observed as ms/ms (homozygote), prob is 1.0? 
                    // Wait, let's re-read: 
                    // calc_prob_offspring_given_selfing_mom_heterozygote_null_model:
                    // if (mf == 0): if sh and (sf == ms): return 1.0 else: return 0.0
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
                if mf == 0 { // Mom is ms/0
                    if isOffspringHom {
                        return 0.5 * (frequencies[Int(sf)] + pNull) + 0.5 * (frequencies[Int(sf)] / (1.0 - pNull))
                    } else {
                        if sf == ms { return 0.5 * frequencies[Int(ss)] }
                        if ss == ms { return 0.5 * frequencies[Int(sf)] }
                        return 0.0
                    }
                } else { // Mom is ms/mf (neither is null)
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
}

public enum BORICE {}
