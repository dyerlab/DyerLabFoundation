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
//  SQLite-backed persistence via ProjectStore. Unlike the old JSON store,
//  this does not round-trip allele lineage (see PopGenStore.swift header).
//

import Foundation

public extension PopGenStore {

    /// Saves this store's current genetic data to a SQLite file at `url`.
    ///
    /// Opens `url` in place if it already exists (preserving whatever
    /// graph/results/log/matrices data it holds) or creates it with just the
    /// `.geneticData` component otherwise — never destroys the file, unlike
    /// the old behavior of recreating it from scratch on every save.
    func save(to url: URL, projectName: String, species: String? = nil, description: String? = nil,
              parentage: ParentageDesign? = nil) async throws {
        let store = ProjectStore()
        try await store.openOrCreate(at: url, components: .geneticData, projectName: projectName,
                                      species: species, description: description)
        try await store.writeGeneticData(matrix: matrix, parentage: parentage, strata: individualStrata)
        await store.close()
    }

    /// Loads a store from a SQLite file at `url`.
    static func load(from url: URL) async throws -> PopGenStore {
        let dataset = try await ProjectStore.load(from: url)
        return PopGenStore(dataset: dataset)
    }
}
