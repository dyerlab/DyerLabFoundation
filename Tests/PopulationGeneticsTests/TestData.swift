//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  TestData.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
@testable import PopulationGenetics

/// Fixtures shared by the tests moved from the app.
enum TestData {

    /// Pop01's mean longitude in `exampleCSV()`, in decimal degrees.
    static let pop01Longitude = -80.13829407

    /// Pop01's mean latitude in `exampleCSV()`, in decimal degrees.
    static let pop01Latitude = 38.39703496

    /// 25 populations × 100 individuals, 20 loci, individuals spread ~10 m apart around each population's centre.
    ///
    /// - Returns: The CSV text.
    /// - Throws: A file error if it can't be read.
    static func exampleCSV() throws -> String {
        try text(of: "example_adult.csv")
    }

    /// *Cornus florida* with ID, Offspring, Longitude, Latitude and 5 loci.
    ///
    /// 22 mothers, of which only families 468 and 474 have offspring (20 each).
    ///
    /// - Returns: The CSV text.
    /// - Throws: A file error if it can't be read.
    static func offspringCSV() throws -> String {
        try text(of: "example_offspring.csv")
    }

    /// *Pinus echinata*: ID, Offspring, Treatment, Cluster, Longitude, Latitude and 10 allozyme loci.
    ///
    /// 46 mothers and 1,230 offspring, families nested in Cluster within Treatment.
    ///
    /// - Returns: The CSV text.
    /// - Throws: A file error if it can't be read.
    static func pechinataCSV() throws -> String {
        try text(of: "example_pechinata.csv")
    }

    /// Imports a genotype CSV.
    ///
    /// - Parameter csv: The CSV text.
    /// - Returns: The genotypes.
    /// - Throws: `GenotypeImportError` if the CSV can't be read.
    static func dataset(_ csv: String) throws -> ImportedDataset {
        try GenotypeTableLayout(csv: csv).importTable(csv: csv)
    }

    private static func text(of name: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/\(name)")
        return try String(contentsOf: url, encoding: .utf8)
    }
}
