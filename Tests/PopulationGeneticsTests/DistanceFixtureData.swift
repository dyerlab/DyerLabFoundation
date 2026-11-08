//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DistanceFixtureData.swift
//  PopulationGeneticsTests
//
//  What the distance and isolation-by-distance tests share with
//  Fixtures/generate_distance_fixtures.R: the fixture file and the arapat
//  individuals genotyped at every locus, the data gstudio and the Swift code
//  agree on.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
@testable import PopulationGenetics

/// The distance fixtures' data.
enum DistanceFixtureData {

    /// The fixture file, `Fixtures/distance_fixtures.json`.
    static var url: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/distance_fixtures.json")
    }

    /// A decoder that reads R's `Inf` and `NaN`.
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Inf",
                                                                        negativeInfinity: "-Inf", nan: "NaN")
        return decoder
    }

    /// The arapat individuals genotyped at every locus, where gstudio's zero-filled missing data doesn't matter.
    static func completeArapat() throws -> ImportedDataset {
        let lines = try ExampleData.text("arapat", extension: "csv").split(separator: "\n", omittingEmptySubsequences: true)
        let complete = lines.dropFirst().filter { line in
            !line.split(separator: ",", omittingEmptySubsequences: false).dropFirst(6).contains { $0.isEmpty }
        }
        return try importPopulationTable(
            csv: ([lines[0]] + complete).joined(separator: "\n"),
            layout: .init(strataColumns: ["Species", "Cluster", "Population"],
                          nameColumn: "ID", latitudeColumn: "Latitude", longitudeColumn: "Longitude"))
    }
}
