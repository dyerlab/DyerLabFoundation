//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DataPlot+Export.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import UniformTypeIdentifiers

public extension DataPlot {

    /// Sends the plot to the clipboard, or prepares it as a file.
    ///
    /// Saving is left to the app, since a file dialog depends on its platform and the app's design.
    ///
    /// - Parameters:
    ///   - output: Where the plot goes.
    ///   - title: The figure's title, which also names any file.
    ///   - legend: The figure's legend.
    ///   - notes: Remarks to keep with any R code as comments.
    ///   - pasteboard: The clipboard to copy to.
    /// - Returns: The file to save, or `nil` if `output` went to the clipboard.
    /// - Throws: ``PlotExportError/renderingFailed`` if the plot can't be rendered, or the table doesn't bind the
    ///   roles the plot's form requires.
    @discardableResult
    func export(_ output: PlotExportOutput,
                title: String,
                legend: String,
                notes: [String] = [],
                pasteboard: DLPasteboard = .system) throws -> PlotExportFile? {
        guard let chunk = rChunk(title: title, legend: legend, notes: notes) else {
            throw PlotExportError.renderingFailed
        }
        let data: Data
        let contentType: UTType
        switch output {
        case .chunkToClipboard:
            pasteboard.copy(text: chunk.fenced)
            return nil
        case .codeToClipboard:
            pasteboard.copy(text: chunk.code)
            return nil
        case .dataToClipboard:
            pasteboard.copy(text: table.tabSeparatedText)
            return nil
        case .png:
            guard let png = pngData(.figure) else { throw PlotExportError.renderingFailed }
            data = png
            contentType = .png
        case .script:
            data = Data(chunk.code.utf8)
            contentType = PlotExportOutput.rSourceType
        case .csv:
            data = Data(table.csvText.utf8)
            contentType = .commaSeparatedText
        }
        return PlotExportFile(data: data, contentType: contentType, suggestedName: chunk.anchor)
    }
}
