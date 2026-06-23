//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  DataTable+CSV.swift
//
//  CSV import/export, delegating to TabularData's type inference.
//

import Foundation
import TabularData

public extension DataTable {

    /// Creates a table from raw CSV data.
    ///
    /// - Parameters:
    ///   - csvData: The contents of a CSV file.
    ///   - types: Optional per-column type overrides; inferred otherwise.
    ///   - options: CSV reading options (delimiter, date strategy, …).
    ///   - roles: An optional initial role mapping.
    init(csvData: Data,
         types: [String: CSVType] = [:],
         options: CSVReadingOptions = .init(),
         roles: [DataColumnRole: String] = [:]) throws {
        let df = try DataFrame(csvData: csvData, types: types, options: options)
        self.init(frame: df, roles: roles)
    }

    /// Creates a table from a CSV file on disk.
    init(contentsOfCSVFile url: URL,
         types: [String: CSVType] = [:],
         options: CSVReadingOptions = .init(),
         roles: [DataColumnRole: String] = [:]) throws {
        let df = try DataFrame(contentsOfCSVFile: url, types: types, options: options)
        self.init(frame: df, roles: roles)
    }

    /// Serialises the backing data frame to CSV data.
    func csvRepresentation(options: CSVWritingOptions = .init()) throws -> Data {
        try frame.csvRepresentation(options: options)
    }
}
