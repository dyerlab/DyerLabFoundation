//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StoredFigure+Drawing.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import UniformTypeIdentifiers

public extension StoredFigure {

    /// The figure as a native plot, or `nil` if its form, columns or roles don't allow one.
    ///
    /// The checks matter because anything can write the file: a column of the wrong kind must leave the figure's
    /// images showing rather than draw nonsense.
    @MainActor
    var plot: DataPlot? {
        guard let form, let table, let y = table.column(for: .y), table.kind(of: y) == .number else { return nil }
        switch form {
        case .histogram, .density: break
        case .bars:
            guard table.column(for: .x) != nil else { return nil }
        case .scatter:
            guard let x = table.column(for: .x), table.kind(of: x) == .number else { return nil }
        }
        return DataPlot(table, form: form, xLabel: xLabel ?? "", yLabel: yLabel ?? "")
    }

    /// The R code that redraws the figure: what was stored, or else code generated from its plot.
    @MainActor
    var resolvedRCode: String? {
        if let rCode, !rCode.isEmpty { return rCode.hasSuffix("\n") ? rCode : rCode + "\n" }
        return plot?.rChunk(title: title, legend: legend)?.code
    }

    /// The exports the figure can provide, given what it holds.
    @MainActor
    var availableOutputs: [PlotExportOutput] {
        PlotExportOutput.allCases.filter { output in
            switch output {
            case .chunkToClipboard, .codeToClipboard, .script: resolvedRCode != nil
            case .dataToClipboard, .csv: table != nil
            case .png: plot != nil || !images.isEmpty
            }
        }
    }

    /// Sends the figure to the clipboard, or prepares it as a file.
    ///
    /// A PNG prefers the stored full-resolution image, which is exactly what its author made, then a native
    /// redraw, then any other stored image.
    ///
    /// - Parameters:
    ///   - output: Where the figure goes.
    ///   - pasteboard: The clipboard to copy to.
    /// - Returns: The file to save, or `nil` if `output` went to the clipboard.
    /// - Throws: ``PlotExportError/plotUnavailable(_:)`` if the figure holds nothing for `output`, or
    ///   ``PlotExportError/renderingFailed`` if it can't be rendered.
    @MainActor
    @discardableResult
    func export(_ output: PlotExportOutput, pasteboard: DLPasteboard = .system) throws -> PlotExportFile? {
        guard availableOutputs.contains(output) else {
            throw PlotExportError.plotUnavailable("This figure doesn't hold what that export needs.")
        }
        let name = RFigureChunk.anchor(for: title)
        switch output {
        case .chunkToClipboard:
            pasteboard.copy(text: RFigureChunk.fenced(resolvedRCode ?? ""))
        case .codeToClipboard:
            pasteboard.copy(text: resolvedRCode ?? "")
        case .dataToClipboard:
            pasteboard.copy(text: table?.tabSeparatedText ?? "")
        case .script:
            return PlotExportFile(data: Data((resolvedRCode ?? "").utf8),
                                  contentType: PlotExportOutput.rSourceType, suggestedName: name)
        case .csv:
            return PlotExportFile(data: Data((table?.csvText ?? "").utf8), contentType: .commaSeparatedText,
                                  suggestedName: name)
        case .png:
            return try imageFile(named: name)
        }
        return nil
    }

    /// Finds or renders the best image of the figure.
    ///
    /// - Parameter name: The file's base name.
    /// - Returns: The file.
    /// - Throws: ``PlotExportError/renderingFailed`` if there is no image and none can be rendered.
    @MainActor
    private func imageFile(named name: String) throws -> PlotExportFile {
        if let image = image(named: Self.figureImageName) { return Self.file(from: image, named: name) }
        if let png = plot?.pngData(.figure) { return PlotExportFile(data: png, contentType: .png, suggestedName: name) }
        guard let image = previewImage ?? images.first else { throw PlotExportError.renderingFailed }
        return Self.file(from: image, named: name)
    }

    private static func file(from image: ResultImage, named name: String) -> PlotExportFile {
        PlotExportFile(data: image.data, contentType: UTType(mimeType: image.mimeType) ?? .png, suggestedName: name)
    }
}
