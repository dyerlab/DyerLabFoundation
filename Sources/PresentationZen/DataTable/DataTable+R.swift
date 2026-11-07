//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DataTable+R.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix

extension DataTable: rSourceConvertible {

    /// R source that recreates the table as a tibble, with values to fifteen significant digits.
    ///
    /// - Returns: A `tibble()` call, which needs the tibble package attached.
    public func toR() -> String {
        toR(significantDigits: 15)
    }

    /// R source that recreates the table as a tibble.
    ///
    /// Columns keep their order. Missing values become `NA`, and dates become UTC `POSIXct` values. A column
    /// that is not a number, date or string comes out as all `NA`.
    ///
    /// - Parameter digits: The significant digits to keep in numbers, which can be fewer when the code is only
    ///   redrawing a figure.
    /// - Returns: A `tibble()` call, which needs the tibble package attached.
    public func toR(significantDigits digits: Int) -> String {
        guard !columnNames.isEmpty else { return "tibble()" }
        let columns = columnNames.map { rColumn($0, digits: digits) }
        return "tibble(\n\(columns.joined(separator: ",\n"))\n)"
    }

    /// Formats one column as a tibble argument.
    ///
    /// - Parameters:
    ///   - name: The column's name.
    ///   - digits: The significant digits to keep in numbers.
    /// - Returns: The column's R code, indented.
    private func rColumn(_ name: String, digits: Int) -> String {
        let prefix = "  \(RLiteral.name(name)) = "
        switch kind(of: name) {
        case .number:
            return RLiteral.vector(numericColumn(name).map { RLiteral.number($0, digits: digits) }, prefix: prefix)
        case .date:
            let items = isoDateColumn(name).map { $0.map(RLiteral.quoted) ?? "NA" }
            return RLiteral.vector(items, prefix: "\(prefix)as.POSIXct( ",
                                   suffix: ", tz = \"UTC\", format = \"%Y-%m-%dT%H:%M:%SZ\" )")
        case .category, .none:
            return RLiteral.vector(stringColumn(name).map { $0.map(RLiteral.quoted) ?? "NA" }, prefix: prefix)
        }
    }
}
