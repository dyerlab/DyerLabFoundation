//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  FigureInteropTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

//  Checks the figure tables against `Fixtures/generate_figures_fixture.R`, which reads a file Swift wrote and writes
//  the file these tests read. See that script for how to regenerate it.

import Foundation
import PresentationZen
import Testing
@testable import PopulationGenetics

@MainActor
struct FigureInteropTests {

    private nonisolated static let fixtureDirectory = ProcessInfo.processInfo.environment["GSTUDIO_FIGURE_FIXTURES"]

    private static let csv = """
        Population,Longitude,Latitude,L1,L2
        A,-80,38,1:1,1:2
        A,-80,40,1:2,1:2
        B,-78,41,2:2,
        B,-76,41,2:2,
        """

    private func fromR() throws -> URL {
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/figures_from_r.gstudio")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let copy = directory.appendingPathComponent("project.gstudio")
        try FileManager.default.copyItem(at: source, to: copy)
        return copy
    }

    // MARK: - Files for R to read

    @Test(.enabled(if: fixtureDirectory != nil))
    func writesTheFilesRReads() async throws {
        let directory = URL(fileURLWithPath: try #require(Self.fixtureDirectory))
        let dataset = try GenotypeTableLayout(csv: Self.csv).importTable(csv: Self.csv)
        let spec = DiversityPlotSpec(response: .He, predictor: .locus)
        let data = DiversityPlotData(spec: spec, dataset: dataset)
        let thumbnail = try #require(data.plot(spec: spec)?.pngData(.thumbnail))
        let diversity = try StoredFigure(title: "He by locus", legend: "Written by Swift.", source: "GeneticStudio",
                                         spec: spec, data: data, thumbnail: thumbnail)
        let when = try #require(ISO8601DateFormatter().date(from: "2026-01-02T03:04:05Z"))
        let missing = StoredFigure(title: "Missing values",
                                   columns: [FigureColumn(name: "value", role: .y, values: .numbers([1, .nan, 3])),
                                             FigureColumn(name: "name", values: .text(["a", "b", nil])),
                                             FigureColumn(name: "when", values: .dates([when, nil, nil]))])
        try await ProjectStore.saveSnapshot(dataset: dataset, figures: [diversity, missing], projectName: "Swift",
                                            to: directory.appendingPathComponent("figures_from_swift.gstudio"))
        try await ProjectStore.saveSnapshot(dataset: dataset, projectName: "Before figures",
                                            to: directory.appendingPathComponent("figures_base.gstudio"))
    }

    // MARK: - Files R wrote

    @Test func rWroteTheSameTablesSwiftCreates() async throws {
        let connection = SQLiteConnection()
        try connection.open(at: try fromR(), mode: .readOnly)
        defer { connection.close() }
        func normal(_ sql: String) -> String {
            sql.replacing("IF NOT EXISTS ", with: "").split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        for (table, statement) in zip(["figures", "figure_columns", "figure_images"],
                                      FiguresSchemaComponent.createStatements) {
            let stmt = try connection.prepare("SELECT sql FROM sqlite_master WHERE name = ?")
            stmt.bind(table, at: 1)
            #expect(try stmt.step())
            #expect(normal(stmt.columnText(at: 0)) == normal(statement))
        }
        try FiguresSchemaComponent.validateSchemaVersion(of: connection)
    }

    @Test func figuresFromROpenAlongsideTheGenotypes() async throws {
        let snapshot = try await ProjectStore.loadSnapshot(from: try fromR())
        #expect(snapshot.dataset?.matrix.individualCount == 4)
        #expect(snapshot.projectName == "Before figures")
        #expect(snapshot.figures.map(\.title) == ["He by population from R", "A picture from R", "Ho, histogram"])
    }

    @Test func aBarChartFromRDrawsNatively() async throws {
        let figure = try #require(try await ProjectStore.loadSnapshot(from: try fromR()).figures.first)
        #expect(figure.id == UUID(uuidString: "6f1e0e52-3f3a-4b63-9a55-1d2c3b4a5f60"))
        #expect(figure.source == "gstudio")
        #expect(figure.legend == "Written by gstudio.")
        #expect(figure.columns == [FigureColumn(name: "population", role: .x, values: .text(["Pop A", "Pop B", nil])),
                                   FigureColumn(name: "He", role: .y, values: .numbers([0.41, nil, 0.5]))])
        #expect(figure.plot?.form == .bars)
        #expect(figure.plot?.pngData(.thumbnail) != nil)
        #expect(figure.resolvedRCode == "ggplot2::ggplot()\n")
        #expect(figure.diversitySpec == nil)
    }

    @Test func aHistogramFromRKeepsItsBins() async throws {
        let figure = try #require(try await ProjectStore.loadSnapshot(from: try fromR()).figures.last)
        #expect(figure.plot?.form == .histogram(bins: 4))
        #expect(figure.columns.first?.values == .numbers([0.1, 0.2, 0.2, 0.6, nil]))
    }

    @Test func anImageFromRShowsAsItIsAndKeepsWhatSwiftDoesntKnow() async throws {
        let figures = try await ProjectStore.loadSnapshot(from: try fromR()).figures
        let figure = figures[1]
        #expect(figure.plot == nil)
        #expect(figure.generator == FigureGenerator(rawValue: "gstudio_ridgeline"))
        #expect(figure.availableOutputs == [.png])
        let file = try #require(try figure.export(.png))
        #expect(file.data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        #expect(file.data == figure.previewImage?.data)
    }

    @Test func savingInSwiftKeepsEverythingRWrote() async throws {
        let url = try fromR()
        let snapshot = try await ProjectStore.loadSnapshot(from: url)
        let saved = url.deletingLastPathComponent().appendingPathComponent("saved.gstudio")
        try await ProjectStore.saveSnapshot(dataset: snapshot.dataset, figures: snapshot.figures,
                                            projectName: "p", to: saved)
        #expect(try await ProjectStore.loadSnapshot(from: saved).figures == snapshot.figures)
    }

    @Test func swiftCanRewriteAFigureRWroteWithoutDuplicatingIt() async throws {
        let url = try fromR()
        let store = ProjectStore()
        try await store.open(at: url)
        var figure = try #require(try await store.figures().first)
        figure.title = "Renamed in Swift"
        try await store.writeFigure(figure)
        let figures = try await store.figures()
        #expect(figures.map(\.title) == ["Renamed in Swift", "A picture from R", "Ho, histogram"])
        #expect(figures.first?.columns.count == 2)
        await store.close()
    }
}
