//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PlotExportOutput.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import UniformTypeIdentifiers

/// Where a plot can be sent, and in what form.
public enum PlotExportOutput: Hashable, Sendable, CaseIterable {
    /// A fenced R chunk on the clipboard.
    case chunkToClipboard
    /// Bare R code on the clipboard.
    case codeToClipboard
    /// The plotted values on the clipboard, tab-separated to paste into a spreadsheet.
    case dataToClipboard
    /// A publication-resolution image in a file.
    case png
    /// Bare R code in a file.
    case script
    /// The plotted values in a CSV file.
    case csv

    /// The type of an exported R script.
    ///
    /// The system registers `.r` as Rez source, which only matters here for naming the file.
    public static let rSourceType = UTType(filenameExtension: "r", conformingTo: .sourceCode) ?? .plainText

    /// Whether the output goes to the clipboard, with no dialog to show it happened.
    public var isClipboard: Bool {
        switch self {
        case .chunkToClipboard, .codeToClipboard, .dataToClipboard: true
        case .png, .script, .csv: false
        }
    }
}
