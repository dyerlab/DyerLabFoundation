//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeMatrixStore+Summary.swift
//  PopulationGenetics
//
//  The read path for `DatasetSummary` — a single scan of the tiny `meta`
//  table, no genotype/graph/result decoding. Intended for callers that only
//  need to classify a file (e.g. an "Open Recent" list choosing an icon for
//  parentage vs. non-parentage, SNP vs. microsatellite) without paying for
//  `readDataset()`.
//

import Foundation

extension GenotypeMatrixStore {

    /// Reads the file's `meta`-table classification: marker composition,
    /// parentage/graph/results presence, and basic project metadata.
    public func readSummary() async throws -> DatasetSummary {
        let connection = try requireConnection()
        var values: [String: String] = [:]
        let stmt = try connection.prepare("SELECT key, value FROM meta")
        while try stmt.step() {
            values[stmt.columnText(at: 0)] = stmt.columnText(at: 1)
        }

        func require(_ key: String) throws -> String {
            guard let value = values[key] else {
                throw PersistenceError.corruptData("missing meta key: \(key)")
            }
            return value
        }

        let markerCompositionString = try require("marker_composition")
        guard let markerComposition = DatasetSummary.MarkerComposition(rawValue: markerCompositionString) else {
            throw PersistenceError.corruptData("invalid marker_composition: \(markerCompositionString)")
        }
        let individualCountString = try require("individual_count")
        guard let individualCount = Int(individualCountString) else {
            throw PersistenceError.corruptData("invalid individual_count: \(individualCountString)")
        }
        let locusCountString = try require("locus_count")
        guard let locusCount = Int(locusCountString) else {
            throw PersistenceError.corruptData("invalid locus_count: \(locusCountString)")
        }
        let createdAtString = try require("created_at")
        guard let createdAt = ISO8601DateFormatter().date(from: createdAtString) else {
            throw PersistenceError.corruptData("invalid created_at: \(createdAtString)")
        }

        let species = try require("species")
        let description = values["description"] ?? ""
        return DatasetSummary(
            projectName: try require("project_name"),
            species: species.isEmpty ? nil : species,
            description: description.isEmpty ? nil : description,
            createdAt: createdAt,
            individualCount: individualCount,
            locusCount: locusCount,
            markerComposition: markerComposition,
            hasParentage: try require("has_parentage") == "true",
            hasGraph: try require("has_graph") == "true",
            hasResults: try require("has_results") == "true")
    }
}
