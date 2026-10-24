//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopGenStore+Frequencies.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.07.13.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

// MARK: - Allele Frequency Calculations

public extension PopGenStore {

    /// Computes allele frequencies and diversity statistics for a named locus.
    ///
    /// - Parameter locusName: The locus's name.
    /// - Returns: Frequencies over every individual; empty if the locus is unknown.
    func getFrequenciesForLocus(locusName: String) -> GenotypeFrequencies {
        GenotypeFrequencies(genotypes: getGenotypesFor(locusName: locusName))
    }

    /// Computes allele frequencies and diversity statistics for a locus.
    ///
    /// - Parameter locus: The locus.
    /// - Returns: Frequencies over every individual; empty if the locus isn't in this store.
    func getGenotypeFrequencies(for locus: Locus) -> GenotypeFrequencies {
        GenotypeFrequencies(genotypes: getGenotypes(for: locus))
    }
}

// MARK: - Stratum-Scoped Convenience Methods

public extension PopGenStore {

    /// Returns a naturally-sorted list of unique locus names with data among a stratum's individuals.
    ///
    /// - Parameter stratum: The stratum whose individuals to scan.
    /// - Returns: The locus names, in natural order.
    func getLocusNames(for stratum: StratumReference) -> [String] {
        var names = Set<String>()
        for individual in getIndividuals(for: stratum) {
            names.formUnion(getLocusNames(for: individual))
        }
        return names.naturalSorted()
    }

    /// Retrieves all genotypes for a named locus across a stratum's individuals
    /// (only individuals with a non-missing call at that locus).
    ///
    /// - Parameters:
    ///   - stratum: The stratum whose individuals to scan.
    ///   - locusName: The locus's name.
    /// - Returns: The non-missing genotypes, in the stratum's member order.
    func getGenotypes(for stratum: StratumReference, locusName: String) -> [Genotype] {
        getIndividuals(for: stratum).compactMap { individual in
            let g = getGenotype(for: individual, locusName: locusName)
            return (g?.isEmpty == false) ? g : nil
        }
    }

    /// Retrieves the locus object for a named locus (the stratum parameter exists
    /// only for API symmetry with the other stratum-scoped queries).
    ///
    /// - Parameters:
    ///   - stratum: Ignored.
    ///   - locusName: The locus's name.
    /// - Returns: The locus, or `nil` if no locus has that name.
    func getLocus(for stratum: StratumReference, named locusName: String) -> Locus? {
        getLocus(named: locusName)
    }

    /// Computes allele frequencies for a locus across a stratum's individuals.
    ///
    /// - Parameters:
    ///   - stratum: The stratum whose individuals to include.
    ///   - locus: The locus.
    /// - Returns: Frequencies over the stratum's non-missing calls.
    func frequenciesForLocus(for stratum: StratumReference, locus: Locus) -> GenotypeFrequencies {
        frequenciesForLocus(for: stratum, locusName: locus.name)
    }

    /// Computes allele frequencies for a named locus across a stratum's individuals.
    ///
    /// - Parameters:
    ///   - stratum: The stratum whose individuals to include.
    ///   - locusName: The locus's name.
    /// - Returns: Frequencies over the stratum's non-missing calls.
    func frequenciesForLocus(for stratum: StratumReference, locusName: String) -> GenotypeFrequencies {
        GenotypeFrequencies(genotypes: getGenotypes(for: stratum, locusName: locusName))
    }
}
