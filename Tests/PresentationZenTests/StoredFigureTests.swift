//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StoredFigureTests.swift
//  PresentationZenTests
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import PresentationZen

@MainActor
struct StoredFigureTests {

    private let scatterColumns = [FigureColumn(name: "group", values: .text(["A", "B"])),
                                  FigureColumn(name: "x", role: .x, values: .numbers([1, 2])),
                                  FigureColumn(name: "y", role: .y, values: .numbers([3, nil]))]

    // MARK: - Drawing

    @Test func columnsRoundTripThroughATable() throws {
        let table = try #require(DataTable(figureColumns: scatterColumns))
        #expect(table.columnNames == ["group", "x", "y"])
        #expect(table.column(for: .x) == "x")
        #expect(table.figureColumns == scatterColumns)
    }

    @Test func columnsThatCantFormATableGiveNone() {
        #expect(DataTable(figureColumns: [FigureColumn(name: "a", values: .numbers([1, 2])),
                                          FigureColumn(name: "b", values: .numbers([1]))]) == nil)
        #expect(DataTable(figureColumns: [FigureColumn(name: "a", values: .numbers([1])),
                                          FigureColumn(name: "a", values: .numbers([1]))]) == nil)
    }

    @Test func aKnownFormWithItsRolesDrawsNatively() {
        let figure = StoredFigure(title: "t", formName: "scatter", columns: scatterColumns)
        #expect(figure.plot?.form == .scatter)
        #expect(figure.plot?.pngData(.thumbnail) != nil)
    }

    @Test func storedFormsReadBack() {
        for form in [PlotForm.histogram(bins: 7), .density, .bars, .scatter] {
            #expect(PlotForm(storedName: form.storedName, bins: form.storedBins) == form)
        }
        #expect(PlotForm(storedName: "histogram", bins: nil) == .histogram(bins: PlotForm.defaultBins))
        #expect(PlotForm(storedName: "histogram", bins: 0) == .histogram(bins: 1))
        #expect(PlotForm(storedName: "ridgeline", bins: nil) == nil)
    }

    @Test func wrongOrMissingColumnsDontDraw() {
        let textY = [FigureColumn(name: "y", role: .y, values: .text(["a"]))]
        #expect(StoredFigure(title: "t", formName: "density", columns: textY).plot == nil)
        let noY = [FigureColumn(name: "x", role: .x, values: .numbers([1]))]
        #expect(StoredFigure(title: "t", formName: "bars", columns: noY).plot == nil)
        let textX = [FigureColumn(name: "x", role: .x, values: .text(["a"])),
                     FigureColumn(name: "y", role: .y, values: .numbers([1]))]
        #expect(StoredFigure(title: "t", formName: "scatter", columns: textX).plot == nil)
        #expect(StoredFigure(title: "t", formName: "bars", columns: textX).plot != nil)
        #expect(StoredFigure(title: "t", columns: textX).plot == nil)
    }

    // MARK: - Exports

    @Test func outputsMatchWhatTheFigureHolds() {
        let image = ResultImage(name: StoredFigure.figureImageName, data: Data([1]))
        #expect(StoredFigure(title: "image only", images: [image]).availableOutputs == [.png])
        let withCode = StoredFigure(title: "t", rCode: "plot(1)", images: [image])
        #expect(withCode.availableOutputs == [.chunkToClipboard, .codeToClipboard, .png, .script])
        #expect(StoredFigure(title: "nothing").availableOutputs.isEmpty)
        let full = StoredFigure(title: "t", formName: "scatter", columns: scatterColumns)
        #expect(full.availableOutputs == PlotExportOutput.allCases)
    }

    @Test func storedCodeWinsAndEndsInANewline() {
        let figure = StoredFigure(title: "t", formName: "scatter", rCode: "plot(1)", columns: scatterColumns)
        #expect(figure.resolvedRCode == "plot(1)\n")
        let generated = StoredFigure(title: "t", formName: "scatter", columns: scatterColumns).resolvedRCode
        #expect(generated?.contains("geom_point()") == true)
    }

    @Test func aPNGPrefersTheStoredFullImageThenARedrawThenAThumbnail() throws {
        let full = ResultImage(name: StoredFigure.figureImageName, mimeType: "image/jpeg", data: Data([1]))
        let thumbnail = ResultImage(name: StoredFigure.thumbnailImageName, data: Data([2]))
        let both = StoredFigure(title: "My Fig", formName: "scatter", columns: scatterColumns,
                                images: [thumbnail, full])
        let stored = try #require(try both.export(.png))
        #expect(stored.data == Data([1]))
        #expect(stored.contentType == .jpeg)
        #expect(stored.suggestedName == "fig-my-fig")

        let redrawn = try #require(try StoredFigure(title: "t", formName: "scatter", columns: scatterColumns,
                                                    images: [thumbnail]).export(.png))
        #expect(redrawn.data.starts(with: [0x89, 0x50, 0x4E, 0x47]))

        let small = try #require(try StoredFigure(title: "t", images: [thumbnail]).export(.png))
        #expect(small.data == Data([2]))
    }

    @Test func anExportTheFigureCantProvideSaysSo() {
        #expect(throws: PlotExportError.self) {
            try StoredFigure(title: "t", images: [ResultImage(name: "figure", data: Data([1]))]).export(.csv)
        }
    }

    #if os(macOS)
    @Test func copyingUsesTheStoredCodeAndValues() throws {
        let pasteboard = DLPasteboard(name: .init(UUID().uuidString))
        defer { pasteboard.releaseGlobally() }
        let figure = StoredFigure(title: "t", formName: "scatter", rCode: "plot(1)\n", columns: scatterColumns)
        #expect(try figure.export(.codeToClipboard, pasteboard: pasteboard) == nil)
        #expect(pasteboard.copiedText == "plot(1)\n")
        try figure.export(.chunkToClipboard, pasteboard: pasteboard)
        #expect(pasteboard.copiedText == "```{r}\nplot(1)\n```\n")
        try figure.export(.dataToClipboard, pasteboard: pasteboard)
        #expect(pasteboard.copiedText == "group\tx\ty\nA\t1\t3\nB\t2\t\n")
    }
    #endif

    @Test func storingATableKeepsItsRolesAndWritesCode() throws {
        let table = try #require(DataTable(figureColumns: scatterColumns))
        var figure = StoredFigure(title: "A figure", legend: "L")
        figure.store(table, form: .histogram(bins: 5), xLabel: "X", yLabel: "Y", notes: ["a note"])
        #expect(figure.formName == "histogram")
        #expect(figure.bins == 5)
        #expect(figure.columns == scatterColumns)
        #expect(figure.rCode?.contains("# a note") == true)
        #expect(figure.rCode?.contains("fig-a-figure") == true)
    }
}
