//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MatrixHeatmapData+CSV.swift
//  PresentationZen
//
//  A matrix as CSV: a header of column names after an empty corner, then one
//  row per row name, as R's `write.csv(m)` writes a matrix and
//  `read.csv(file, row.names = 1)` reads it back. Values keep full
//  precision, missing ones are `NA`, and names with commas or quotes are
//  quoted.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import UniformTypeIdentifiers

public extension MatrixHeatmapData {

    /// The matrix as CSV text, with row and column names.
    var csvText: String {
        let header = ([""] + columnNames).map(Self.quoted).joined(separator: ",")
        let rows = rowNames.enumerated().map { row, name in
            ([Self.quoted(name)] + (0..<columnNames.count).map { column in
                let value = value(row: row, column: column)
                return value.isFinite ? String(format: "%.15g", value) : "NA"
            }).joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    /// The matrix as a CSV file.
    ///
    /// - Parameter name: The file's name, without its extension; characters a file name can't hold become dashes.
    /// - Returns: The file.
    func csvFile(named name: String) -> PlotExportFile {
        let base = name.replacingOccurrences(of: "[/:\\\\]", with: "-", options: .regularExpression)
        return PlotExportFile(data: Data(csvText.utf8), contentType: .commaSeparatedText, suggestedName: base + ".csv")
    }

    private static func quoted(_ text: String) -> String {
        guard text.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
