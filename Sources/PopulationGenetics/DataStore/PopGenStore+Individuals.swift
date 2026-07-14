//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopGenStore+Individuals.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//

import Foundation

// MARK: - Individual Management

public extension PopGenStore {

    /// Fetches all individuals from the store, sorted naturally by name.
    func fetchIndividuals() -> [Individual] {
        individuals.naturalSorted(by: \.name)
    }

    /// Creates and inserts a new individual into the store.
    ///
    /// Extends every existing locus's allele/lineage columns with a missing
    /// placeholder for the new individual — O(locusCount), an accepted cost of
    /// dense columnar storage.
    ///
    /// - Parameters:
    ///   - name: The name or identifier for the individual.
    ///   - latitude: The sampling latitude (optional spatial coordinate).
    ///   - longitude: The sampling longitude (optional spatial coordinate).
    /// - Returns: The newly created `Individual`.
    @discardableResult
    func addIndividual(name: String, latitude: Double? = nil, longitude: Double? = nil) -> Individual {
        let newIndividual = Individual(name: name, latitude: latitude, longitude: longitude)
        individualOrdinal[newIndividual.id] = individuals.count
        individuals.append(newIndividual)

        for j in loci.indices {
            leftAlleleIdx[j].append(AlleleCodebook.nullIndex)
            rightAlleleIdx[j].append(AlleleCodebook.nullIndex)
            leftLineage[j].append(Int8(Genotype.UnknownLineage))
            rightLineage[j].append(Int8(Genotype.UnknownLineage))
        }

        return newIndividual
    }

    /// Retrieves a specific individual by their unique identifier.
    func getIndividual(id: UUID) -> Individual? {
        guard let ordinal = individualOrdinal[id] else { return nil }
        return individuals[ordinal]
    }

    /// Updates an individual's metadata (name/coordinates) in place.
    ///
    /// No-op if `individual.id` isn't already present — this replaces metadata
    /// at an existing ordinal, it does not insert a new row (use `addIndividual`
    /// for that, since a new row requires extending every locus's columns).
    func updateIndividual(_ individual: Individual) {
        guard let ordinal = individualOrdinal[individual.id] else { return }
        individuals[ordinal] = individual
    }

    /// Deletes an individual and its genotype calls at every locus.
    ///
    /// O(locusCount + individualCount): removes this individual's row from every
    /// locus's columns and rebuilds the ordinal index for the individuals that shift.
    func deleteIndividual(id: UUID) {
        guard let ordinal = individualOrdinal[id] else { return }

        individuals.remove(at: ordinal)
        for j in loci.indices {
            leftAlleleIdx[j].remove(at: ordinal)
            rightAlleleIdx[j].remove(at: ordinal)
            leftLineage[j].remove(at: ordinal)
            rightLineage[j].remove(at: ordinal)
        }

        for reference in individualStrata[id] ?? [] {
            strataMembers[reference.id]?.remove(id)
        }
        individualStrata.removeValue(forKey: id)

        individualOrdinal = Dictionary(uniqueKeysWithValues: individuals.enumerated().map { ($1.id, $0) })
    }
}
