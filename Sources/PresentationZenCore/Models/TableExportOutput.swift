//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  TableExportOutput.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import UniformTypeIdentifiers

/// Where a results table goes: the clipboard or a file.
public enum TableExportOutput: Hashable, Sendable, CaseIterable {
    /// A fenced R chunk that prints the table, on the clipboard.
    case chunkToClipboard
    /// Bare R code on the clipboard.
    case codeToClipboard
    /// A Markdown pipe table on the clipboard.
    case markdownToClipboard
    /// The values on the clipboard, tab-separated to paste into a spreadsheet.
    case dataToClipboard
    /// A Markdown table in a file.
    case markdown
    /// Bare R code in a file.
    case script
    /// The values in a CSV file.
    case csv

    /// The type of an exported Markdown file.
    public static let markdownType = UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText

    /// Whether the output goes to the clipboard, with no dialog to show it happened.
    public var isClipboard: Bool {
        switch self {
        case .chunkToClipboard, .codeToClipboard, .markdownToClipboard, .dataToClipboard: true
        case .markdown, .script, .csv: false
        }
    }
}
