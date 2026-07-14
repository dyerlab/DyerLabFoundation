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
// PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//

import Foundation

// MARK: - Allele Frequency Calculations

public extension PopGenStore {

    /// Computes allele frequencies and diversity statistics for a named locus.
    func getFrequenciesForLocus(locusName: String) -> GenotypeFrequencies {
        GenotypeFrequencies(genotypes: getGenotypesFor(locusName: locusName))
    }

    /// Computes allele frequencies and diversity statistics for a locus.
    func getGenotypeFrequencies(for locus: Locus) -> GenotypeFrequencies {
        GenotypeFrequencies(genotypes: getGenotypes(for: locus))
    }
}

// MARK: - Stratum-Scoped Convenience Methods

public extension PopGenStore {

    /// Returns a naturally-sorted list of unique locus names with data among a stratum's individuals.
    func getLocusNames(for stratum: StratumReference) -> [String] {
        var names = Set<String>()
        for individual in getIndividuals(for: stratum) {
            names.formUnion(getLocusNames(for: individual))
        }
        return names.naturalSorted()
    }

    /// Retrieves all genotypes for a named locus across a stratum's individuals
    /// (only individuals with a non-missing call at that locus).
    func getGenotypes(for stratum: StratumReference, locusName: String) -> [Genotype] {
        getIndividuals(for: stratum).compactMap { individual in
            let g = getGenotype(for: individual, locusName: locusName)
            return (g?.isEmpty == false) ? g : nil
        }
    }

    /// Retrieves the locus object for a named locus (the stratum parameter exists
    /// only for API symmetry with the other stratum-scoped queries).
    func getLocus(for stratum: StratumReference, named locusName: String) -> Locus? {
        getLocus(named: locusName)
    }

    /// Computes allele frequencies for a locus across a stratum's individuals.
    func frequenciesForLocus(for stratum: StratumReference, locus: Locus) -> GenotypeFrequencies {
        frequenciesForLocus(for: stratum, locusName: locus.name)
    }

    /// Computes allele frequencies for a named locus across a stratum's individuals.
    func frequenciesForLocus(for stratum: StratumReference, locusName: String) -> GenotypeFrequencies {
        GenotypeFrequencies(genotypes: getGenotypes(for: stratum, locusName: locusName))
    }
}
