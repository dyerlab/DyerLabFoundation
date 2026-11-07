//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DataPlotExportTests.swift
//  PresentationZenTests
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import PresentationZen

@MainActor
struct DataPlotExportTests {

    private static let values = [0.1, 0.2, 0.2, 0.3, 0.5, 0.8]

    private var plot: DataPlot {
        DataPlot(DataTable(vector: Self.values, name: "He"), form: .histogram(bins: 4), xLabel: "He", yLabel: "Count")
    }

    private func pixelWidth(of png: Data) throws -> Int {
        let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil)).width
    }

    // MARK: - Images

    @Test func everyFormRendersAPNGOfTheRequestedSize() throws {
        let bars = DataTable(numbers: ["v": [1, 2]], strings: ["n": ["a", "b"]], roles: [.x: "n", .y: "v"])
        let points = DataTable(numbers: ["x": [38, 39, 41], "y": [1, 2, 3]], roles: [.x: "x", .y: "y"])
        let plots = [plot,
                     DataPlot(DataTable(vector: Self.values), form: .density),
                     DataPlot(bars, form: .bars),
                     DataPlot(points, form: .scatter)]
        for plot in plots {
            #expect(try pixelWidth(of: try #require(plot.pngData(.figure))) == 2400)
            #expect(try pixelWidth(of: try #require(plot.pngData(.thumbnail))) == 480)
        }
    }

    @Test func histogramOfIdenticalValuesStillRenders() throws {
        let plot = DataPlot(DataTable(vector: [0.5, 0.5]), form: .histogram(bins: 10))
        #expect(try pixelWidth(of: try #require(plot.pngData(.thumbnail))) == 480)
    }

    // MARK: - Files

    @Test func filesCarryTheirTypeAndAnAnchorName() throws {
        let png = try #require(try plot.export(.png, title: "He by locus", legend: ""))
        #expect(png.contentType == .png)
        #expect(png.suggestedName == "fig-he-by-locus")
        #expect(png.data.starts(with: [0x89, 0x50, 0x4E, 0x47]))

        let script = try #require(try plot.export(.script, title: "t", legend: ""))
        #expect(script.contentType.preferredFilenameExtension == "r")
        #expect(String(decoding: script.data, as: UTF8.self).contains("geom_histogram"))

        let csv = try #require(try plot.export(.csv, title: "t", legend: ""))
        #expect(csv.contentType == .commaSeparatedText)
        #expect(String(decoding: csv.data, as: UTF8.self).hasPrefix("He\n0.1\n"))
    }

    @Test func tableThatCantBeDrawnReportsWhy() {
        let plot = DataPlot(DataTable(numbers: ["x": [1]]), form: .density)
        #expect(throws: PlotExportError.renderingFailed) {
            try plot.export(.csv, title: "t", legend: "")
        }
    }

    // MARK: - Clipboard

    #if os(macOS)
    @Test func clipboardOutputsGoToThePasteboardAndReturnNoFile() throws {
        let pasteboard = DLPasteboard(name: .init(UUID().uuidString))
        defer { pasteboard.releaseGlobally() }
        let chunk = try #require(plot.rChunk(title: "t", legend: "l"))

        #expect(try plot.export(.chunkToClipboard, title: "t", legend: "l", pasteboard: pasteboard) == nil)
        #expect(pasteboard.copiedText == chunk.fenced)

        #expect(try plot.export(.codeToClipboard, title: "t", legend: "l", pasteboard: pasteboard) == nil)
        #expect(pasteboard.copiedText == chunk.code)

        #expect(try plot.export(.dataToClipboard, title: "t", legend: "l", pasteboard: pasteboard) == nil)
        #expect(pasteboard.copiedText == "He\n0.1\n0.2\n0.2\n0.3\n0.5\n0.8\n")
    }
    #endif

    @Test func outputsSayWhetherTheyGoToTheClipboard() {
        #expect(PlotExportOutput.allCases.filter(\.isClipboard) == [.chunkToClipboard, .codeToClipboard,
                                                                    .dataToClipboard])
    }
}
