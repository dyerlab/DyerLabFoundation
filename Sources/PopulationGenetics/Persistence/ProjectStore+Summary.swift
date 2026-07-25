//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ProjectStore+Summary.swift
//  PopulationGenetics
//
//  The read path for `DatasetSummary` — a single scan of the tiny `meta`
//  table, no genotype/graph/result decoding. Intended for callers that only
//  need to classify a file (e.g. an "Open Recent" list choosing an icon for
//  parentage vs. non-parentage, SNP vs. microsatellite, graph-only vs.
//  genetic-data) without paying for `readDataset()`.
//

import Foundation

extension ProjectStore {

    /// Reads the file's `meta`-table classification: project identity
    /// (always present), plus whichever component classifications are
    /// available given what this file was created with.
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

        let createdAtString = try require("created_at")
        guard let createdAt = ISO8601DateFormatter().date(from: createdAtString) else {
            throw PersistenceError.corruptData("invalid created_at: \(createdAtString)")
        }
        let species = try require("species")
        let description = values["description"] ?? ""

        var individualCount: Int?
        var locusCount: Int?
        var markerComposition: DatasetSummary.MarkerComposition?
        var hasParentage: Bool?
        // These four are only written once `writeGeneticData` has actually run —
        // a file created with `.geneticData` but never yet written reads as
        // "component present, no data" (nil), same as hasGraph/hasResults/etc.
        if values[GeneticDataSchemaComponent.hasFlagKey] == "true" {
            let markerCompositionString = try require("marker_composition")
            guard let composition = DatasetSummary.MarkerComposition(rawValue: markerCompositionString) else {
                throw PersistenceError.corruptData("invalid marker_composition: \(markerCompositionString)")
            }
            markerComposition = composition
            let individualCountString = try require("individual_count")
            guard let count = Int(individualCountString) else {
                throw PersistenceError.corruptData("invalid individual_count: \(individualCountString)")
            }
            individualCount = count
            let locusCountString = try require("locus_count")
            guard let count = Int(locusCountString) else {
                throw PersistenceError.corruptData("invalid locus_count: \(locusCountString)")
            }
            locusCount = count
            hasParentage = try require("has_parentage") == "true"
        }

        return DatasetSummary(
            projectName: try require("project_name"),
            species: species.isEmpty ? nil : species,
            description: description.isEmpty ? nil : description,
            createdAt: createdAt,
            individualCount: individualCount,
            locusCount: locusCount,
            markerComposition: markerComposition,
            hasParentage: hasParentage,
            hasGraph: values[GraphSchemaComponent.hasFlagKey].map { $0 == "true" },
            hasResults: values[ResultsSchemaComponent.hasFlagKey].map { $0 == "true" },
            hasLog: values[LogSchemaComponent.hasFlagKey].map { $0 == "true" },
            hasMatrices: values[MatricesSchemaComponent.hasFlagKey].map { $0 == "true" })
    }
}
