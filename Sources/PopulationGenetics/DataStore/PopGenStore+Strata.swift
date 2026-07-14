//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopGenStore+Strata.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//

import Foundation
import CoreLocation

// MARK: - Hierarchical Stratum Access

public extension PopGenStore {

    /// Fetches all strata known to the store, sorted naturally by level.
    func getAllStrata() -> [StratumReference] {
        Array(allStrata.values).naturalSorted(by: \.level)
    }

    /// Fetches all strata within a specific hierarchical level, sorted naturally by name.
    func getStrataWithin(level: String) -> [StratumReference] {
        Array(allStrata.values)
            .filter { $0.level == level }
            .naturalSorted(by: \.name)
    }

    /// Retrieves a specific stratum by name and hierarchical level.
    func getStratum(named: String, within: String) -> StratumReference? {
        guard let id = strataCatalog[within]?[named] else { return nil }
        return allStrata[id]
    }

    /// Retrieves all individuals belonging to the (first) stratum with the given name,
    /// regardless of level.
    func getIndividualsWithinStratum(named: String) -> [Individual] {
        guard let stratum = allStrata.values.first(where: { $0.name == named }) else { return [] }
        return getIndividuals(for: stratum)
    }

    /// Creates (or reuses) a stratum at the given name/level, returning its canonical reference.
    ///
    /// Every call with the same `(name, level)` pair returns a reference sharing
    /// the same `id`, so individuals tagged separately still land in one stratum.
    @discardableResult
    func addStratum(name: String, within level: String) -> StratumReference {
        if let existingID = strataCatalog[level]?[name], let existing = allStrata[existingID] {
            return existing
        }
        let reference = StratumReference(level: level, name: name)
        allStrata[reference.id] = reference
        strataCatalog[level, default: [:]][name] = reference.id
        return reference
    }

    /// Tags an individual as belonging to a stratum (many-to-many relationship).
    func tagIndividual(_ individualID: UUID, with reference: StratumReference) {
        guard individualOrdinal[individualID] != nil else { return }
        allStrata[reference.id] = reference
        strataCatalog[reference.level, default: [:]][reference.name] = reference.id

        if !(individualStrata[individualID]?.contains(where: { $0.id == reference.id }) ?? false) {
            individualStrata[individualID, default: []].append(reference)
        }
        strataMembers[reference.id, default: []].insert(individualID)
    }

    /// Retrieves all individuals for a specific stratum.
    func getIndividuals(for stratum: StratumReference) -> [Individual] {
        (strataMembers[stratum.id] ?? []).compactMap { getIndividual(id: $0) }
    }

    /// Retrieves all strata for a specific individual.
    func getStrata(for individual: Individual) -> [StratumReference] {
        individualStrata[individual.id] ?? []
    }

    /// Number of individuals tagged with a stratum.
    func individualCount(for stratum: StratumReference) -> Int {
        strataMembers[stratum.id]?.count ?? 0
    }
}

// MARK: - Spatial Data

public extension PopGenStore {

    /// Returns the bounding box `(minLon, maxLon, minLat, maxLat)` encompassing
    /// all individuals in a stratum.
    func boundingBox(for stratum: StratumReference) -> (Double, Double, Double, Double) {
        getIndividuals(for: stratum).coordinates.bounds()
    }

    /// Computes the geographic centroid of all individuals in a stratum.
    func centroid(for stratum: StratumReference) -> CLLocationCoordinate2D? {
        getIndividuals(for: stratum).coordinates.center
    }
}
