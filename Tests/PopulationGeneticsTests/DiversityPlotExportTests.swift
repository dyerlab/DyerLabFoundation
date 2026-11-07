//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DiversityPlotExportTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import PresentationZen
import Testing
@testable import PopulationGenetics

/// A diversity plot reaches PresentationZen as a table in the right columns and form.
@MainActor
struct DiversityPlotExportTests {

    /// Two populations; B has no genotypes at L2.
    private static let csv = """
        Population,Longitude,Latitude,L1,L2
        A,-80,38,1:1,1:2
        A,-80,40,1:2,1:2
        B,-78,41,2:2,
        B,-76,41,2:2,
        """

    private func data(_ spec: DiversityPlotSpec) throws -> DiversityPlotData {
        let dataset = try GenotypeTableLayout(csv: Self.csv).importTable(csv: Self.csv)
        return DiversityPlotData(spec: spec, dataset: dataset)
    }

    private func table(_ spec: DiversityPlotSpec) throws -> DataTable {
        try #require(try data(spec).dataTable(spec: spec))
    }

    // MARK: - Columns

    @Test func distributionIsOneColumn() throws {
        #expect(try table(DiversityPlotSpec(response: .He)).csvText == "He\n0.46875\n0.5\n")
    }

    @Test func barsNameTheirCategories() throws {
        #expect(try table(DiversityPlotSpec(response: .He, predictor: .locus)).csvText
                == "locus,He\nL1,0.46875\nL2,0.5\n")
    }

    @Test func scatterHasGroupPredictorAndStatistic() throws {
        #expect(try table(DiversityPlotSpec(response: .He, predictor: .latitude)).csvText
                == "group,latitude,He\nA,39,0.4375\nB,41,0\n")
        #expect(try table(DiversityPlotSpec(response: .He, predictor: .sampleSize)).csvText
                == "group,sample_size,He\nA,2,0.4375\nB,2,0\n")
    }

    @Test func unavailablePlotHasNoTableOrPlot() throws {
        let spec = DiversityPlotSpec(predictor: .population, locus: "Gone")
        #expect(try data(spec).dataTable(spec: spec) == nil)
        #expect(try data(spec).plot(spec: spec) == nil)
    }

    // MARK: - Forms

    @Test func specChoosesTheForm() throws {
        func form(_ spec: DiversityPlotSpec) throws -> PlotForm? { try data(spec).plot(spec: spec)?.form }
        #expect(try form(DiversityPlotSpec(bins: 7)) == .histogram(bins: 7))
        #expect(try form(DiversityPlotSpec(style: .density)) == .density)
        #expect(try form(DiversityPlotSpec(predictor: .locus)) == .bars)
        #expect(try form(DiversityPlotSpec(predictor: .latitude)) == .scatter)
    }

    // MARK: - R

    @Test func scatterCodeIsComplete() throws {
        let spec = DiversityPlotSpec(response: .He, predictor: .latitude)
        let chunk = try #require(try data(spec).plot(spec: spec)?.rChunk(title: "He by latitude",
                                                                         legend: "Each point is a population."))
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
              labs( x = "Latitude (decimal degrees)", y = "Expected heterozygosity (He)" )

            """)
    }

    @Test func densityAxisIsLabelled() throws {
        let spec = DiversityPlotSpec(response: .He, style: .density)
        let chunk = try #require(try data(spec).plot(spec: spec)?.rChunk(title: "t", legend: ""))
        #expect(chunk.code.contains("y = \"Density\""))
    }

    @Test func omittedItemsBecomeNotes() throws {
        let spec = DiversityPlotSpec(response: .He, predictor: .locus, sample: .group(name: "B"))
        #expect(try data(spec).exportNotes == ["Not shown (no data): L2"])
        #expect(try data(DiversityPlotSpec(response: .He, predictor: .locus)).exportNotes.isEmpty)
    }

    // MARK: - Images

    @Test func everyFormAndAnUnavailablePlotRender() throws {
        let specs = [DiversityPlotSpec(),
                     DiversityPlotSpec(style: .density),
                     DiversityPlotSpec(predictor: .population),
                     DiversityPlotSpec(predictor: .latitude),
                     DiversityPlotSpec(predictor: .population, locus: "Gone")]
        for spec in specs {
            #expect(DiversityChart(data: try data(spec), spec: spec).pngData(.thumbnail) != nil)
        }
    }
}
