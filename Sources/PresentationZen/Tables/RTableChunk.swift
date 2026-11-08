//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RTableChunk.swift
//  PresentationZen
//
//  The table counterpart of `RFigureChunk`: a Quarto chunk that rebuilds a
//  results table as a tibble and prints it with knitr::kable(), labelled
//  `tbl-…` so a manuscript can cross-reference it.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// R code that prints a results table in a Quarto or R Markdown document.
///
/// ## Usage
///
/// ```swift
/// let chunk = RTableChunk(title: "AMOVA among populations", legend: "", table: table)
/// pasteboard.copy(text: chunk.fenced)
/// ```
public struct RTableChunk: Equatable, Sendable {

    /// The table's anchor, such as `tbl-amova-among-populations`, also the base name of its exported file.
    public let anchor: String
    /// The bare R code, for an existing chunk, a script or the console.
    public let code: String
    /// The code in a fenced chunk, to paste anywhere in a Markdown document.
    public var fenced: String { RFigureChunk.fenced(code) }

    /// Builds the chunk.
    ///
    /// - Parameters:
    ///   - title: The table's title.
    ///   - legend: The table's legend.
    ///   - table: The values.
    ///   - decimals: The decimal places `kable()` shows.
    ///   - notes: Remarks to keep with the code as comments.
    public init(title: String, legend: String, table: DataTable, decimals: Int = DataTable.defaultDecimals,
                notes: [String] = []) {
        anchor = Self.anchor(for: title)
        let options = ["#| label: \(anchor)",
                       "#| tbl-cap: \(RLiteral.quoted(Self.caption(title: title, legend: legend)))",
                       "#| echo: false",
                       "#| message: false"] + notes.map { "# " + RLiteral.singleLine($0) }
        code = """
            \(options.joined(separator: "\n"))

            library( tidyverse )
            library( knitr )

            \(table.toR()) |>
              kable( digits = \(decimals), na = "" )

            """
    }

    /// Makes a title into a URL- and file-safe anchor: `"AMOVA among populations"` becomes
    /// `tbl-amova-among-populations`.
    ///
    /// - Parameter title: The table's title.
    /// - Returns: The anchor; `tbl-table` if the title has no usable characters.
    public static func anchor(for title: String) -> String {
        let figure = RFigureChunk.anchor(for: title)
        return figure == "fig-plot" ? "tbl-table" : "tbl-" + figure.dropFirst("fig-".count)
    }

    /// The caption: the title as a sentence, then the legend.
    ///
    /// - Parameters:
    ///   - title: The table's title.
    ///   - legend: The table's legend.
    /// - Returns: The caption.
    public static func caption(title: String, legend: String) -> String {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let heading = title.isEmpty || title.hasSuffix(".") ? title : "\(title)."
        let legend = legend.trimmingCharacters(in: .whitespacesAndNewlines)
        return [heading, legend].filter { !$0.isEmpty }.joined(separator: " ")
    }
}
