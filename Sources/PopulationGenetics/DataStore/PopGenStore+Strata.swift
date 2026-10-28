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
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.07.13.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import CoreLocation

// MARK: - Hierarchical Stratum Access

public extension PopGenStore {

    /// Fetches all strata known to the store, sorted naturally by level.
    ///
    /// - Returns: Every stratum, in natural level order.
    func getAllStrata() -> [StratumReference] {
        Array(allStrata.values).naturalSorted(by: \.level)
    }

    /// Fetches all strata within a specific hierarchical level, sorted naturally by name.
    ///
    /// - Parameter level: The hierarchical level, e.g. `"Population"`.
    /// - Returns: The level's strata, in natural name order.
    func getStrataWithin(level: String) -> [StratumReference] {
        Array(allStrata.values)
            .filter { $0.level == level }
            .naturalSorted(by: \.name)
    }

    /// Retrieves a specific stratum by name and hierarchical level.
    ///
    /// - Parameters:
    ///   - named: The stratum's name.
    ///   - within: The stratum's level.
    /// - Returns: The stratum, or `nil` if none matches.
    func getStratum(named: String, within: String) -> StratumReference? {
        guard let id = strataCatalog[within]?[named] else { return nil }
        return allStrata[id]
    }

    /// Retrieves all individuals belonging to the (first) stratum with the given name,
    /// regardless of level.
    ///
    /// - Parameter named: The stratum's name.
    /// - Returns: The stratum's members, or an empty array if no stratum has that name.
    func getIndividualsWithinStratum(named: String) -> [Individual] {
        guard let stratum = allStrata.values.first(where: { $0.name == named }) else { return [] }
        return getIndividuals(for: stratum)
    }

    /// Creates (or reuses) a stratum at the given name/level, returning its canonical reference.
    ///
    /// Every call with the same `(name, level)` pair returns a reference sharing
    /// the same `id`, so individuals tagged separately still land in one stratum.
    ///
    /// - Parameters:
    ///   - name: The stratum's name.
    ///   - level: The stratum's level.
    /// - Returns: The canonical reference for `(name, level)`.
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
    ///
    /// - Parameters:
    ///   - individualID: The individual's identifier; an unknown id does nothing.
    ///   - reference: The stratum to add it to.
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
    ///
    /// - Parameter stratum: The stratum.
    /// - Returns: The stratum's members.
    func getIndividuals(for stratum: StratumReference) -> [Individual] {
        (strataMembers[stratum.id] ?? []).compactMap { getIndividual(id: $0) }
    }

    /// Retrieves all strata for a specific individual.
    ///
    /// - Parameter individual: The individual.
    /// - Returns: The strata the individual is tagged with.
    func getStrata(for individual: Individual) -> [StratumReference] {
        individualStrata[individual.id] ?? []
    }

    /// Number of individuals tagged with a stratum.
    ///
    /// - Parameter stratum: The stratum.
    /// - Returns: The member count.
    func individualCount(for stratum: StratumReference) -> Int {
        strataMembers[stratum.id]?.count ?? 0
    }
}

// MARK: - Spatial Data

public extension PopGenStore {

    /// Returns the bounding box `(minLon, maxLon, minLat, maxLat)` encompassing
    /// all individuals in a stratum.
    ///
    /// - Parameter stratum: The stratum.
    func boundingBox(for stratum: StratumReference) -> (Double, Double, Double, Double) {
        getIndividuals(for: stratum).coordinates.bounds()
    }

    /// Computes the geographic centroid of all individuals in a stratum.
    ///
    /// - Parameter stratum: The stratum.
    /// - Returns: The centroid, or `nil` if no member has coordinates.
    func centroid(for stratum: StratumReference) -> CLLocationCoordinate2D? {
        getIndividuals(for: stratum).coordinates.center
    }
}
