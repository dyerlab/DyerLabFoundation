//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopGenStore+Persistence.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//
//  SQLite-backed persistence via GenotypeMatrixStore. Unlike the old JSON store,
//  this does not round-trip allele lineage (see PopGenStore.swift header).
//

import Foundation

public extension PopGenStore {

    /// Saves this store's current state to a SQLite file at `url`, overwriting
    /// any existing file there.
    func save(to url: URL, projectName: String, species: String? = nil, description: String? = nil,
              parentage: ParentageDesign? = nil) async throws {
        try await GenotypeMatrixStore.save(matrix, parentage: parentage, strata: individualStrata,
                                            projectName: projectName, species: species, description: description,
                                            to: url)
    }

    /// Loads a store from a SQLite file at `url`.
    static func load(from url: URL) async throws -> PopGenStore {
        let dataset = try await GenotypeMatrixStore.load(from: url)
        return PopGenStore(dataset: dataset)
    }
}
