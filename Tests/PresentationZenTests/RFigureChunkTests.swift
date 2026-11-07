//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RFigureChunkTests.swift
//  PresentationZenTests
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix
import TabularData
import Testing
@testable import PresentationZen

struct RFigureChunkTests {

    private static var categories: DataTable {
        var frame = DataFrame()
        frame.append(column: Column(name: "locus", contents: ["L1", "L2"]))
        frame.append(column: Column(name: "Ae", contents: [1.6, 2.0]))
        return DataTable(frame: frame, roles: [.x: "locus", .y: "Ae"])
    }

    private func code(_ table: DataTable, _ form: PlotForm, notes: [String] = []) throws -> String {
        try #require(RFigureChunk(title: "A plot", legend: "A legend.", table: table, form: form, xLabel: "X",
                                  yLabel: "Y", notes: notes)).code
    }

    // MARK: - Forms

    @Test func scatterIsComplete() throws {
        var frame = DataFrame()
        frame.append(column: Column(name: "group", contents: ["A", "B"]))
        frame.append(column: Column(name: "latitude", contents: [39.0, 41.0]))
        frame.append(column: Column(name: "He", contents: [0.4375, 0.0]))
        let table = DataTable(frame: frame, roles: [.x: "latitude", .y: "He"])
        let chunk = try #require(RFigureChunk(title: "He by latitude", legend: "Each point is a population.",
                                              table: table, form: .scatter, xLabel: "Latitude", yLabel: "He"))
        #expect(chunk.code == """
            #| label: fig-he-by-latitude
            #| fig-cap: "He by latitude. Each point is a population."
            #| echo: false
            #| message: false

            library( tidyverse )

            tibble(
              group = c( "A", "B" ),
              latitude = c( 39, 41 ),
              He = c( 0.4375, 0 )
            ) |>
              ggplot( aes( latitude, He ) ) +
              geom_point() +
              labs( x = "Latitude", y = "He" )

            """)
    }

    @Test func barsKeepTheirOrder() throws {
        let text = try code(Self.categories, .bars)
        #expect(text.contains("ggplot( aes( fct_inorder( locus ), Ae ) )"))
        #expect(text.contains("geom_col()"))
        #expect(!text.contains("axis.text.x"))
    }

    @Test func manyBarsRotateTheirLabels() throws {
        var frame = DataFrame()
        frame.append(column: Column(name: "name", contents: (0..<9).map { "N\($0)" }))
        frame.append(column: Column(name: "value", contents: (0..<9).map(Double.init)))
        let text = try code(DataTable(frame: frame, roles: [.x: "name", .y: "value"]), .bars)
        #expect(text.contains("axis.text.x"))
    }

    @Test func histogramUsesTheChartsBins() throws {
        let text = try code(DataTable(vector: [0.46875, 0.5], name: "He"), .histogram(bins: 4))
        #expect(text.contains("ggplot( aes( He ) )"))
        #expect(text.contains("geom_histogram( breaks = seq( 0.46875, 0.5, length.out = 5 ), closed = \"left\" )"))
    }

    @Test func histogramOfIdenticalValuesHasOneBin() throws {
        let text = try code(DataTable(vector: [0.5, 0.5], name: "He"), .histogram(bins: 10))
        #expect(text.contains("geom_histogram( bins = 1 )"))
    }

    @Test func densityExtendsPastTheDataAsTheChartDoes() throws {
        let text = try code(DataTable(vector: [0.1, 0.2, 0.4], name: "He"), .density)
        #expect(text.contains("geom_density()"))
        #expect(text.contains("xlim( "))
    }

    @Test func tableWithoutTheRolesItsFormNeedsHasNoChunk() {
        let unbound = DataTable(numbers: ["x": [1], "y": [2]])
        #expect(RFigureChunk(title: "t", legend: "", table: unbound, form: .density, xLabel: "", yLabel: "") == nil)
        let noX = DataTable(vector: [1], name: "y")
        #expect(RFigureChunk(title: "t", legend: "", table: noX, form: .scatter, xLabel: "", yLabel: "") == nil)
    }

    // MARK: - Text

    @Test func notesBecomeComments() throws {
        let text = try code(Self.categories, .bars, notes: ["Not shown (no data): L3"])
        #expect(text.contains("#| message: false\n# Not shown (no data): L3\n"))
    }

    @Test func textIsEscapedForRAndKeptOnOneLine() throws {
        let chunk = try #require(RFigureChunk(title: "Done.", legend: "Says \"hi\"\nC:\\x", table: Self.categories,
                                              form: .bars, xLabel: "", yLabel: ""))
        #expect(chunk.code.contains(#"#| fig-cap: "Done. Says \"hi\" C:\\x""#))
    }

    @Test func fencedChunkWrapsTheCode() throws {
        let chunk = try #require(RFigureChunk(title: "t", legend: "", table: Self.categories, form: .bars, xLabel: "",
                                              yLabel: ""))
        #expect(chunk.fenced == "```{r}\n\(chunk.code)```\n")
        #expect(!chunk.code.contains("```"))
    }

    @Test func awkwardTitlesMakeUsableAnchors() {
        #expect(RFigureChunk.anchor(for: "Ae — across  Loci (2026)!") == "fig-ae-across-loci-2026")
        #expect(RFigureChunk.anchor(for: "Diversité") == "fig-diversite")
        #expect(RFigureChunk.anchor(for: "—") == "fig-plot")
    }
}
