//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GeneticDistances.swift
//  PopulationGenetics
//
//  The genetic distances the Distance page offers, as gstudio's
//  genetic_distance() computes them (Fixtures/generate_distance_fixtures.R).
//
//  Missing data is where they part from gstudio, which fills a missing
//  genotype with zeros (no alleles) and so counts it as sharing nothing. Here
//  each locus uses only the units genotyped there: strata's frequencies come
//  from the individuals genotyped at a locus, and a pair compares only the
//  loci both are genotyped at. Measures that are averages (Bray-Curtis, Dps)
//  average over those loci; sums (Cavalli-Sforza, Euclidean, AMOVA) are scaled
//  up to all the loci, so pairs with and without gaps stay on one scale; Nei's
//  Jxy, Jx and Jy are summed over them. Without missing data, every value is
//  gstudio's.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Genetic distances among individuals and among strata.
public enum GeneticDistances {

    // MARK: - Among individuals

    /// Bray-Curtis distances among individuals: one minus the proportion of alleles a pair shares (Bowcock et al.
    /// 1994), averaged over the loci both are genotyped at.
    ///
    /// At a locus each individual's alleles are proportions (½ each for a diploid, 1 for a single allele), and the
    /// pair shares the sum of the smaller of each allele's two proportions.
    ///
    /// - Parameters:
    ///   - matrix: The genotypes.
    ///   - ordinals: The individuals, in matrix order.
    /// - Returns: The distances, in `ordinals` order; `NaN` for a pair with no locus in common.
    public static func brayCurtis(matrix: GenotypeMatrix, ordinals: [Int]) -> GeneticDistanceMatrix {
        let n = ordinals.count
        var shared = [Double](repeating: 0, count: n * (n - 1) / 2)
        var common = [Double](repeating: 0, count: shared.count)
        for column in matrix.columns {
            let alleles = ordinals.map { column.alleles(at: $0).flatMap(proportions) }
            var k = 0
            for i in 0..<n {
                for j in (i + 1)..<n {
                    defer { k += 1 }
                    guard let a = alleles[i], let b = alleles[j] else { continue }
                    var sum = 0.0
                    for (allele, p) in a { if let q = b[allele] { sum += min(p, q) } }
                    shared[k] += sum
                    common[k] += 1
                }
            }
        }
        let packed = zip(shared, common).map { $1 > 0 ? 1 - $0 / $1 : .nan }
        return GeneticDistanceMatrix(count: n, packed: packed)
    }

    /// AMOVA distances among individuals: Smouse & Peakall's (1999) squared distances, summed over loci.
    ///
    /// - Parameters:
    ///   - matrix: The genotypes.
    ///   - ordinals: The individuals, in matrix order.
    /// - Returns: The distances, in `ordinals` order. A pair not genotyped at every locus is scaled up to all of them.
    public static func amova(matrix: GenotypeMatrix, ordinals: [Int]) -> GeneticDistanceMatrix {
        matrix.geneticDistance(strategy: .rescaleToTotalLoci).submatrix(indices: ordinals)
    }

    /// An individual's alleles at a locus as proportions, or `nil` when it isn't genotyped there.
    private static func proportions(_ pair: (UInt8, UInt8)) -> [UInt8: Double]? {
        switch (pair.0 != 0, pair.1 != 0) {
        case (true, true): pair.0 == pair.1 ? [pair.0: 1] : [pair.0: 0.5, pair.1: 0.5]
        case (true, false): [pair.0: 1]
        case (false, true): [pair.1: 1]
        case (false, false): nil
        }
    }

    // MARK: - Among strata

    /// A distance among strata computed from their allele frequencies.
    public enum FrequencyMeasure: Sendable {
        /// Nei's (1978) unbiased genetic distance.
        case nei
        /// Cavalli-Sforza & Edwards' (1967) chord distance, summed over loci.
        case cavalli
        /// The shared-allele distance, `1 − Ps`, averaged over loci.
        case dps
        /// The Euclidean distance between the strata's allele frequencies over all loci.
        case euclidean
    }

    /// One stratum's allele frequencies and sample size at a locus.
    private struct LocusSample {
        /// The frequency of each allele slot (slot 0, the NULL allele, left out).
        let frequencies: [Double]
        /// The number of individuals genotyped.
        let individuals: Double
    }

    /// Distances among strata from their allele frequencies.
    ///
    /// - Parameters:
    ///   - measure: The distance.
    ///   - matrix: The genotypes.
    ///   - strata: Each stratum's individuals, as matrix ordinals.
    /// - Returns: The distances, in `strata` order; `NaN` for a pair with no locus in common, or (Nei's) with no
    ///   allele in common.
    public static func frequencyDistance(_ measure: FrequencyMeasure, matrix: GenotypeMatrix,
                                         strata: [[Int]]) -> GeneticDistanceMatrix {
        let samples: [[LocusSample?]] = strata.map { rows in
            matrix.columns.map { column in
                let counts = column.frequencies(over: rows)
                guard counts.N > 0 else { return nil }
                return LocusSample(frequencies: counts.frequencies(), individuals: counts.numGenos)
            }
        }
        let loci = Double(matrix.locusCount)
        let n = strata.count
        var packed: [Double] = []
        packed.reserveCapacity(n * (n - 1) / 2)
        for i in 0..<n {
            for j in (i + 1)..<n {
                let pairs = zip(samples[i], samples[j]).compactMap { a, b in a.flatMap { a in b.map { (a, $0) } } }
                packed.append(pairs.isEmpty ? .nan : distance(measure, pairs, loci: loci))
            }
        }
        return GeneticDistanceMatrix(count: n, packed: packed)
    }

    /// One pair of strata's distance over the loci both are genotyped at.
    private static func distance(_ measure: FrequencyMeasure, _ pairs: [(LocusSample, LocusSample)],
                                 loci: Double) -> Double {
        let scale = loci / Double(pairs.count)
        switch measure {
        case .nei:
            var jxy = 0.0, jx = 0.0, jy = 0.0
            for (x, y) in pairs {
                jxy += zip(x.frequencies, y.frequencies).reduce(0) { $0 + $1.0 * $1.1 }
                jx += unbiasedHomozygosity(x)
                jy += unbiasedHomozygosity(y)
            }
            let bottom = (jx * jy).squareRoot()
            return bottom > 0 && jxy > 0 ? -log(jxy / bottom) : .nan
        case .cavalli:
            let sum = pairs.reduce(0.0) { total, pair in
                let overlap = zip(pair.0.frequencies, pair.1.frequencies).reduce(0) { $0 + ($1.0 * $1.1).squareRoot() }
                return total + 2 / .pi * (2 * max(0, 1 - overlap)).squareRoot()
            }
            return sum * scale
        case .dps:
            let shared = pairs.reduce(0.0) { total, pair in
                total + zip(pair.0.frequencies, pair.1.frequencies).reduce(0) { $0 + min($1.0, $1.1) }
            }
            return 1 - shared / Double(pairs.count)
        case .euclidean:
            let squares = pairs.reduce(0.0) { total, pair in
                total + zip(pair.0.frequencies, pair.1.frequencies).reduce(0) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) }
            }
            return (squares * scale).squareRoot()
        }
    }

    /// Nei's (1978) unbiased within-stratum homozygosity, `(2n Σp² − 1) / (2n − 1)`.
    private static func unbiasedHomozygosity(_ sample: LocusSample) -> Double {
        let twoN = 2 * sample.individuals
        let squares = sample.frequencies.reduce(0) { $0 + $1 * $1 }
        return twoN > 1 ? (twoN * squares - 1) / (twoN - 1) : squares
    }
}
