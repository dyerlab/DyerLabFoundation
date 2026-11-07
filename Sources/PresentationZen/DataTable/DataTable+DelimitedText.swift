//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DataTable+DelimitedText.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import TabularData

public extension DataTable {

    /// The table as CSV text, for a file.
    ///
    /// Numbers keep fifteen significant digits, which is all a spreadsheet keeps and avoids binary noise like
    /// `0.30000000000000004`. Missing and non-finite values are left empty, and only fields that need quotes
    /// get them.
    var csvText: String {
        delimitedText(separator: ",") { field in
            let needsQuotes = field.contains { $0 == "," || $0 == "\"" || $0.isNewline }
            return needsQuotes ? "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\"" : field
        }
    }

    /// The table as tab-separated text, to paste into a spreadsheet's cells.
    ///
    /// A spreadsheet treats the two forms differently: a CSV file opens as columns, but pasted comma-separated
    /// text lands in a single column, while pasted tab-separated text splits into cells. Whitespace inside a
    /// field collapses to single spaces, so each value stays in its own cell.
    var tabSeparatedText: String {
        delimitedText(separator: "\t") { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
    }

    /// Joins the table's fields into lines.
    ///
    /// - Parameters:
    ///   - separator: The text between fields.
    ///   - clean: Makes one field safe to appear between separators.
    /// - Returns: A header line and one line per row, each ending in a newline.
    private func delimitedText(separator: String, cleaning clean: (String) -> String) -> String {
        let cells = columnNames.map(textFields)
        let rows = (0..<rowCount).map { row in cells.map { $0[row] } }
        let lines = [columnNames] + rows
        return lines.map { $0.map(clean).joined(separator: separator) }.joined(separator: "\n") + "\n"
    }

    /// Formats a column's values for delimited text.
    ///
    /// - Parameter name: The column.
    /// - Returns: One field per row.
    private func textFields(_ name: String) -> [String] {
        switch kind(of: name) {
        case .number:
            return numericColumn(name).map { value in
                value.flatMap { $0.isFinite ? String(format: "%.15g", $0) : nil } ?? ""
            }
        case .date:
            return isoDateColumn(name).map { $0 ?? "" }
        case .category, .none:
            return stringColumn(name).map { $0 ?? "" }
        }
    }
}

extension DataTable {

    /// Reads a date column as ISO 8601 text in UTC.
    ///
    /// - Parameter name: The column.
    /// - Returns: One string per row, `nil` where the date is missing.
    func isoDateColumn(_ name: String) -> [String?] {
        frame[name, Date.self].map { $0?.ISO8601Format() }
    }
}
