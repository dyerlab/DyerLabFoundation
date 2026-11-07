//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ProjectFileTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import PresentationZen
import Matrix
import Testing
@testable import PopulationGenetics

struct ProjectFileTests {

    private static let raster = GeographicBounds(west: -80, east: -79, south: 37, north: 38).flatMap { bounds in
        Raster(name: "elevation", rows: 1, cols: 2, bounds: bounds, epsg: 4326, values: [1, 2])
    }

    @Test func figuresAndRastersSurviveTheFileBytes() async throws {
        let figure = StoredFigure(title: "t", createdAt: Date(timeIntervalSince1970: 0),
                                  columns: [FigureColumn(name: "He", role: .y, values: .numbers([1]))])
        let raster = RasterAttachment(raster: try #require(Self.raster), description: "elevation")
        let snapshot = ProjectSnapshot(projectName: "p", rasters: [raster], figures: [figure])
        let loaded = try await ProjectFile.snapshot(from: try await ProjectFile.data(for: snapshot))
        #expect(loaded.figures == [figure])
        #expect(loaded.rasters.map(\.description) == ["elevation"])
    }

    @Test func refreshingLeavesAProjectWithoutGenotypesAlone() throws {
        let figure = try StoredFigure(title: "t", legend: "", source: "s", spec: DiversityPlotSpec(), data: nil,
                                      thumbnail: nil)
        #expect(ProjectSnapshot(projectName: "p", figures: [figure]).refreshingFigures().figures == [figure])
    }

    @Test func refreshingFillsInTheValuesAndKeepsEverythingElse() throws {
        let csv = """
            Population,Longitude,Latitude,L1,L2
            A,-80,38,1:1,1:2
            A,-80,40,1:2,1:2
            B,-78,41,2:2,
            B,-76,41,2:2,
            """
        let figure = try StoredFigure(title: "t", legend: "", source: "s",
                                      spec: DiversityPlotSpec(response: .He, predictor: .locus), data: nil,
                                      thumbnail: nil)
        let snapshot = ProjectSnapshot(projectName: "p", species: "s", metadata: ["k": "v"],
                                       dataset: try TestData.dataset(csv), figures: [figure])
        let refreshed = snapshot.refreshingFigures()
        #expect(refreshed.figures.first?.columns.map(\.name) == ["locus", "He"])
        #expect(refreshed.projectName == "p")
        #expect(refreshed.species == "s")
        #expect(refreshed.metadata["k"] == "v")
        #expect(refreshed.dataset != nil)
    }
}
