//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//
//  Created by Rodney Dyer on 4/23/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

import Foundation

// MARK: - Population Factory

/// Creates N diploid individuals whose genotypes are sampled from supplied per-locus allele frequencies.
///
/// Each locus must be **biallelic**: exactly two entries in its frequency dictionary.  Frequencies per
/// locus must sum to 1.0.  Alleles are sorted lexicographically before being stored so the convention
/// is consistent with `mateGenotypes`.
///
/// A fresh `PopGenStore` is returned alongside the individuals so the caller can merge or
/// use it directly.  All individuals are registered in a stratum named `populationName` at
/// hierarchical level `"Population"`.
///
/// - Parameters:
///   - locusFrequencies: Dictionary keyed by locus name → `[alleleName: frequency]`.
///   - populationName: Assigned to every individual's stratum at level `"Population"`.
///   - size: Number of diploid individuals to create.
/// - Returns: A tuple of the new store and the array of created individuals.
///
/// ## Example
///
/// ```swift
/// let freqs: [String: [String: Double]] = [
///     "L01": ["01": 0.4, "02": 0.6],
///     "L02": ["01": 0.7, "02": 0.3]
/// ]
/// let (store, individuals) = makePopulation(locusFrequencies: freqs,
///                                           populationName: "Pop01",
///                                           size: 100)
/// ```
public func makePopulation(
    locusFrequencies: [String: [String: Double]],
    populationName: String,
    size: Int
) -> (store: PopGenStore, individuals: [Individual]) {

    let store = PopGenStore()

    // Register all loci up front so indices are stable
    let sortedLocusNames = locusFrequencies.keys.naturalSorted()
    for name in sortedLocusNames {
        store.addLocus(name: name)
    }

    let stratum = store.addStratum(name: populationName, within: "Population")

    var individuals: [Individual] = []
    individuals.reserveCapacity(size)

    for i in 0..<size {
        let name = String(format: "%@-%03d", populationName, i + 1)
        let individual = store.addIndividual(name: name)

        for locusName in sortedLocusNames {
            guard let freqMap = locusFrequencies[locusName] else { continue }

            let a1 = sampleAllele(from: freqMap)
            let a2 = sampleAllele(from: freqMap)

            // Lexicographic sort matches mateGenotypes convention
            let (left, right) = a1 <= a2 ? (a1, a2) : (a2, a1)
            store.setGenotype(individual: individual, locusName: locusName, leftAllele: left, rightAllele: right)
        }

        store.tagIndividual(individual.id, with: stratum)
        individuals.append(individual)
    }

    return (store, individuals)
}


// MARK: - Private helpers

/// Samples a single allele from a frequency map using the cumulative distribution function.
///
/// - Parameter freqMap: Dictionary of `[alleleName: frequency]`; frequencies must sum to 1.0.
/// - Returns: The sampled allele name, or the last allele as a fallback.
private func sampleAllele(from freqMap: [String: Double]) -> String {
    let sortedAlleles = freqMap.keys.naturalSorted()
    let draw = Double.random(in: 0..<1)
    var cumulative = 0.0
    for allele in sortedAlleles {
        cumulative += freqMap[allele] ?? 0.0
        if draw < cumulative {
            return allele
        }
    }
    return sortedAlleles.last ?? ""
}
