//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DataTable+TableExport.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import UniformTypeIdentifiers

public extension DataTable {

    /// Sends the table to the clipboard as a results table, or prepares it as a file.
    ///
    /// Saving is left to the app, since a file dialog depends on its platform and the app's design.
    ///
    /// - Parameters:
    ///   - output: Where the table goes.
    ///   - title: The table's title, which also names any file.
    ///   - legend: The table's legend.
    ///   - rCode: R code to use instead of generating it, such as a saved table's code.
    ///   - notes: Remarks to keep with generated R code as comments.
    ///   - pasteboard: The clipboard to copy to.
    /// - Returns: The file to save, or `nil` if `output` went to the clipboard.
    @discardableResult
    func exportTable(_ output: TableExportOutput,
                     title: String,
                     legend: String,
                     rCode: String? = nil,
                     notes: [String] = [],
                     pasteboard: DLPasteboard = .system) -> PlotExportFile? {
        let anchor = RTableChunk.anchor(for: title)
        let code = rCode.flatMap { $0.isEmpty ? nil : ($0.hasSuffix("\n") ? $0 : $0 + "\n") }
            ?? RTableChunk(title: title, legend: legend, table: self, notes: notes).code
        let markdown = markdownText(caption: RTableChunk.caption(title: title, legend: legend), anchor: anchor)
        let data: Data
        let contentType: UTType
        switch output {
        case .chunkToClipboard:
            pasteboard.copy(text: RFigureChunk.fenced(code))
            return nil
        case .codeToClipboard:
            pasteboard.copy(text: code)
            return nil
        case .markdownToClipboard:
            pasteboard.copy(text: markdown)
            return nil
        case .dataToClipboard:
            pasteboard.copy(text: tabSeparatedText)
            return nil
        case .markdown:
            data = Data(markdown.utf8)
            contentType = TableExportOutput.markdownType
        case .script:
            data = Data(code.utf8)
            contentType = PlotExportOutput.rSourceType
        case .csv:
            data = Data(csvText.utf8)
            contentType = .commaSeparatedText
        }
        return PlotExportFile(data: data, contentType: contentType, suggestedName: anchor)
    }
}
