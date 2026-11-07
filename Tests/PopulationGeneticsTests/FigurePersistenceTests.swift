//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  FigurePersistenceTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import PresentationZen
import Testing
@testable import PopulationGenetics

struct FigurePersistenceTests {

    private static let figure = StoredFigure(
        title: "He by latitude",
        legend: "Each point is a population.",
        source: "GeneticStudio",
        formName: "scatter",
        xLabel: "Latitude",
        yLabel: "He",
        generator: .diversityPlot,
        spec: "{\"response\":\"He\"}",
        rCode: "ggplot()\n",
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        columns: [FigureColumn(name: "group", values: .text(["A", nil, "C"])),
                  FigureColumn(name: "latitude", role: .x, values: .numbers([38.5, 39, nil])),
                  FigureColumn(name: "He", role: .y, values: .numbers([0.1, 0.2, 0.3])),
                  FigureColumn(name: "when", values: .dates([Date(timeIntervalSince1970: 0), nil, nil]))],
        images: [ResultImage(name: StoredFigure.thumbnailImageName, width: 2, height: 1, data: Data([1, 2, 3]))])

    private func withFile<T>(_ body: (URL) async throws -> T) async throws -> T {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        return try await body(directory.appendingPathComponent("project.gstudio"))
    }

    // MARK: - Round trips

    @Test func everyFieldSurvivesASnapshot() async throws {
        try await withFile { url in
            try await ProjectStore.saveSnapshot(figures: [Self.figure], projectName: "p", to: url)
            let loaded = try await ProjectStore.loadSnapshot(from: url)
            #expect(loaded.figures == [Self.figure])
        }
    }

    @Test func snapshotKeepsListOrder() async throws {
        try await withFile { url in
            let figures = ["b", "a", "c"].map { StoredFigure(title: $0, createdAt: Date(timeIntervalSince1970: 0)) }
            try await ProjectStore.saveSnapshot(figures: figures, projectName: "p", to: url)
            #expect(try await ProjectStore.loadSnapshot(from: url).figures.map(\.title) == ["b", "a", "c"])
        }
    }

    @Test func unknownFormAndGeneratorAreKept() async throws {
        try await withFile { url in
            let figure = StoredFigure(title: "t", formName: "ridgeline", generator: FigureGenerator(rawValue: "future"),
                                      spec: "{\"x\":1}", createdAt: Date(timeIntervalSince1970: 0))
            try await ProjectStore.saveSnapshot(figures: [figure], projectName: "p", to: url)
            let loaded = try #require(try await ProjectStore.loadSnapshot(from: url).figures.first)
            #expect(loaded == figure)
            #expect(loaded.form == nil)
            #expect(loaded.diversitySpec == nil)
        }
    }

    @Test func nonFiniteValuesAreStoredAsMissing() async throws {
        try await withFile { url in
            let figure = StoredFigure(title: "t", createdAt: Date(timeIntervalSince1970: 0),
                                      columns: [FigureColumn(name: "x", values: .numbers([.nan, .infinity, 1]))])
            try await ProjectStore.saveSnapshot(figures: [figure], projectName: "p", to: url)
            let loaded = try #require(try await ProjectStore.loadSnapshot(from: url).figures.first)
            #expect(loaded.columns.first?.values == .numbers([nil, nil, 1]))
        }
    }

    // MARK: - Incremental writes

    @Test func rewritingAFigureKeepsItsPlaceAndReplacesItsChildren() async throws {
        try await withFile { url in
            let store = ProjectStore()
            try await store.create(at: url, components: .figures, projectName: "p")
            var first = StoredFigure(title: "first", createdAt: Date(timeIntervalSince1970: 0),
                                     columns: [FigureColumn(name: "a", values: .numbers([1]))],
                                     images: [ResultImage(name: "thumbnail", data: Data([1]))])
            try await store.writeFigure(first)
            try await store.writeFigure(StoredFigure(title: "second"))
            first.title = "renamed"
            first.columns = [FigureColumn(name: "b", values: .numbers([2]))]
            first.images = []
            try await store.writeFigure(first)
            let figures = try await store.figures()
            #expect(figures.map(\.title) == ["renamed", "second"])
            #expect(figures.first?.columns.map(\.name) == ["b"])
            #expect(figures.first?.images.isEmpty == true)
            await store.close()
        }
    }

    @Test func removingAFigureRemovesItsChildren() async throws {
        try await withFile { url in
            let store = ProjectStore()
            try await store.create(at: url, components: .figures, projectName: "p")
            try await store.writeFigure(Self.figure)
            #expect(try await store.figure(id: Self.figure.id) != nil)
            try await store.removeFigure(id: Self.figure.id)
            #expect(try await store.figures().isEmpty)
            // Writing it again would hit a primary key if a child row had been left behind.
            try await store.writeFigure(Self.figure)
            #expect(try await store.figures().count == 1)
            await store.close()
        }
    }

    @Test func columnsOfDifferentLengthsAreRejected() async throws {
        try await withFile { url in
            let store = ProjectStore()
            try await store.create(at: url, components: .figures, projectName: "p")
            let bad = StoredFigure(title: "t", columns: [FigureColumn(name: "a", values: .numbers([1, 2])),
                                                         FigureColumn(name: "b", values: .numbers([1]))])
            await #expect(throws: PersistenceError.self) { try await store.writeFigure(bad) }
            #expect(try await store.figures().isEmpty)
            await store.close()
        }
    }

    @Test func aFileWithoutTheComponentReportsItAndLoadsEmpty() async throws {
        try await withFile { url in
            let store = ProjectStore()
            try await store.create(at: url, components: .log, projectName: "p")
            await #expect(throws: PersistenceError.componentNotPresent("figures")) {
                try await store.writeFigure(Self.figure)
            }
            await store.close()
            #expect(try await ProjectStore.loadSnapshot(from: url).figures.isEmpty)
        }
    }

    // MARK: - Diversity plots

    private static let csv = """
        Population,Longitude,Latitude,L1,L2
        A,-80,38,1:1,1:2
        A,-80,40,1:2,1:2
        B,-78,41,2:2,
        B,-76,41,2:2,
        """

    @Test func diversityFigureStoresEverythingRNeeds() throws {
        let dataset = try GenotypeTableLayout(csv: Self.csv).importTable(csv: Self.csv)
        let spec = DiversityPlotSpec(response: .He, predictor: .latitude)
        let figure = try StoredFigure(title: "He by latitude", legend: "L", source: "GeneticStudio", spec: spec,
                                      data: DiversityPlotData(spec: spec, dataset: dataset), thumbnail: Data([1]))
        #expect(figure.diversitySpec == spec)
        #expect(figure.generator == .diversityPlot)
        #expect(figure.formName == "scatter")
        #expect(figure.columns.map(\.name) == ["group", "latitude", "He"])
        #expect(figure.columns.map(\.role) == [nil, .x, .y])
        #expect(figure.rCode?.contains("geom_point()") == true)
        #expect(figure.previewImage?.data == Data([1]))
    }

    @Test func refreshingFollowsTheGenotypesButKeepsTheThumbnail() throws {
        let dataset = try GenotypeTableLayout(csv: Self.csv).importTable(csv: Self.csv)
        let spec = DiversityPlotSpec(response: .He, predictor: .locus)
        let figure = try StoredFigure(title: "t", legend: "", source: "s", spec: spec, data: nil, thumbnail: Data([9]))
        #expect(figure.columns.isEmpty)
        let refreshed = figure.refreshed(from: dataset)
        #expect(refreshed.columns.last?.values == .numbers([0.46875, 0.5]))
        #expect(refreshed.images == figure.images)
    }

    @Test func aPlotThatCantBeDrawnKeepsItsLastValues() throws {
        let dataset = try GenotypeTableLayout(csv: Self.csv).importTable(csv: Self.csv)
        let columns = [FigureColumn(name: "He", role: .y, values: .numbers([1]))]
        var figure = StoredFigure(title: "t", formName: "density", columns: columns)
        try figure.setDiversitySpec(DiversityPlotSpec(predictor: .population, locus: "Gone"), data: nil)
        #expect(figure.refreshed(from: dataset).columns == columns)
    }

    @Test func figuresFromOtherSourcesAreNotRefreshed() throws {
        let dataset = try GenotypeTableLayout(csv: Self.csv).importTable(csv: Self.csv)
        let plain = StoredFigure(title: "From R", source: "gstudio", formName: "bars",
                                 columns: [FigureColumn(name: "He", role: .y, values: .numbers([1]))])
        #expect(plain.refreshed(from: dataset) == plain)
    }
}
