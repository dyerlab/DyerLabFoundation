//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DataTable+Markdown.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

public extension DataTable {

    /// The number of decimals a results table shows by default.
    static let defaultDecimals = 4

    /// A column's values as a results table shows them.
    ///
    /// A numeric column whose values are all whole numbers, such as degrees of freedom, shows them without
    /// decimals; other numbers get `decimals` places. Missing and non-finite values are empty.
    ///
    /// - Parameters:
    ///   - name: The column.
    ///   - decimals: The decimal places for numbers that aren't whole.
    /// - Returns: One string per row.
    func displayTexts(_ name: String, decimals: Int = DataTable.defaultDecimals) -> [String] {
        switch kind(of: name) {
        case .number:
            let values = numericColumn(name)
            let whole = values.allSatisfy { value in value.map { !$0.isFinite || $0 == $0.rounded() } ?? true }
            let format = whole ? "%.0f" : "%.\(decimals)f"
            return values.map { value in value.flatMap { $0.isFinite ? String(format: format, $0) : nil } ?? "" }
        case .date:
            return Array(frame[name, Date.self]).map { $0?.formatted(date: .abbreviated, time: .omitted) ?? "" }
        case .category, .none:
            return stringColumn(name).map { $0 ?? "" }
        }
    }

    /// The table as a Markdown pipe table, with numbers right-aligned and text left-aligned.
    ///
    /// - Parameters:
    ///   - caption: A caption, written beneath the table in Pandoc's `: caption` form, or `nil` for none.
    ///   - anchor: A cross-reference label such as `tbl-amova`, added to the caption.
    ///   - decimals: The decimal places for numbers that aren't whole.
    /// - Returns: The table, ending in a newline.
    func markdownText(caption: String? = nil, anchor: String? = nil,
                      decimals: Int = DataTable.defaultDecimals) -> String {
        let names = columnNames
        let cells = names.map { displayTexts($0, decimals: decimals) }
        func line(_ fields: [String]) -> String {
            "| " + fields.map { $0.replacingOccurrences(of: "|", with: "\\|") }.joined(separator: " | ") + " |"
        }
        let rule = "|" + names.map { kind(of: $0) == .number ? "---:" : ":---" }.joined(separator: "|") + "|"
        var lines = [line(names), rule] + (0..<rowCount).map { row in line(cells.map { $0[row] }) }
        if let caption, !caption.isEmpty {
            lines += ["", ": " + caption.split(whereSeparator: \.isNewline).joined(separator: " ")
                      + (anchor.map { " {#\($0)}" } ?? "")]
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
