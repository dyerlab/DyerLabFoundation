//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DiversityPlotDataTests.swift
//  PopulationGeneticsTests
//
//  Expected values are worked by hand from `csv`. For example, Pop A at L1 has
//  genotypes 1:1 and 1:2, so p = (3/4, 1/4) and He = 1 - 10/16 = 0.375.
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import PopulationGenetics

struct DiversityPlotDataTests {

    /// Two populations; B has no genotypes at L2.
    private static let csv = """
        Population,Longitude,Latitude,L1,L2
        A,-80,38,1:1,1:2
        A,-80,40,1:2,1:2
        B,-78,41,2:2,
        B,-76,41,2:2,
        """

    private static func dataset(_ csv: String) throws -> ImportedDataset {
        try GenotypeTableLayout(csv: csv).importTable(csv: csv)
    }

    private func data(_ spec: DiversityPlotSpec) throws -> DiversityPlotData {
        DiversityPlotData(spec: spec, dataset: try Self.dataset(Self.csv))
    }

    private func categories(_ spec: DiversityPlotSpec) throws -> [String: Double] {
        guard case .categories(let rows) = try data(spec).content else {
            Issue.record("expected categories")
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.name, $0.value) })
    }

    private func close(_ a: Double?, _ b: Double) -> Bool {
        a.map { abs($0 - b) < 1e-9 } ?? false
    }

    // MARK: - Forms

    @Test func predictorChoosesTheForm() {
        #expect(DiversityPlotSpec().form == .distribution)
        #expect(DiversityPlotSpec(predictor: .locus).form == .bars)
        #expect(DiversityPlotSpec(predictor: .population).form == .bars)
        #expect(DiversityPlotSpec(predictor: .latitude).form == .scatter)
        #expect(DiversityPlotSpec(predictor: .sampleSize).form == .scatter)
    }

    // MARK: - Per-locus values

    @Test func pooledValuePerLocus() throws {
        let values = try categories(DiversityPlotSpec(response: .He, predictor: .locus))
        #expect(close(values["L1"], 0.46875))
        #expect(close(values["L2"], 0.5))
    }

    @Test func meanWithinPopulationsDiffersFromPooled() throws {
        let values = try categories(DiversityPlotSpec(response: .He, predictor: .locus, sample: .meanWithinGroups))
        #expect(close(values["L1"], 0.1875))
        #expect(close(values["L2"], 0.5))
    }

    @Test func oneGroupsLocusWithoutGenotypesIsOmittedNotPlottedAsOne() throws {
        let plot = try data(DiversityPlotSpec(response: .He, predictor: .locus, sample: .group(name: "B")))
        #expect(plot.content == .categories([.init(name: "L1", value: 0)]))
        #expect(plot.omitted == ["L2"])
    }

    // MARK: - Per-group values

    @Test func populationValueAveragesOnlyLociWithGenotypes() throws {
        let values = try categories(DiversityPlotSpec(response: .He, predictor: .population))
        #expect(close(values["A"], 0.4375))
        #expect(close(values["B"], 0))
    }

    @Test func eachStatisticMatchesItsDefinition() throws {
        func a(_ response: DiversityType) throws -> Double? {
            try categories(DiversityPlotSpec(response: response, predictor: .population, locus: "L1"))["A"]
        }
        #expect(close(try a(.A), 2))
        #expect(close(try a(.A95), 2))
        #expect(close(try a(.Ae), 1.6))
        #expect(close(try a(.Ho), 0.5))
        #expect(close(try a(.He), 0.375))
    }

    @Test func scatterUsesTheGroupsMeanCoordinate() throws {
        let plot = try data(DiversityPlotSpec(response: .He, predictor: .latitude))
        guard case .points(let points) = plot.content else {
            Issue.record("expected points")
            return
        }
        #expect(points.map(\.name) == ["A", "B"])
        #expect(close(points.first?.x, 39))
        #expect(close(points.first?.y, 0.4375))
        #expect(close(points.last?.x, 41))
        #expect(plot.xLabel == "Latitude (decimal degrees)")
    }

    @Test func populationWithoutCoordinatesIsOmittedFromScatter() throws {
        let csv = """
            Population,Longitude,Latitude,L1
            A,-80,38,1:2
            B,,,1:2
            """
        let dataset = try Self.dataset(csv)
        let plot = DiversityPlotData(spec: DiversityPlotSpec(predictor: .latitude), dataset: dataset)
        #expect(plot.omitted == ["B"])
        guard case .points(let points) = plot.content else {
            Issue.record("expected points")
            return
        }
        #expect(points.map(\.name) == ["A"])
    }

    // MARK: - Distributions

    @Test func distributionHasOneValuePerUnit() throws {
        guard case .distribution(let loci) = try data(DiversityPlotSpec(response: .He)).content,
              case .distribution(let populations) = try data(DiversityPlotSpec(response: .He,
                                                                               unit: .population)).content,
              case .distribution(let both) = try data(DiversityPlotSpec(response: .He,
                                                                        unit: .locusWithinPopulation)).content else {
            Issue.record("expected distributions")
            return
        }
        #expect(loci.count == 2)
        #expect(populations.count == 2)
        // A at L1 and L2, B only at L1.
        #expect(both.count == 3)
    }

    // MARK: - Stale references

    @Test func missingLocusIsReportedNotDrawn() throws {
        let plot = try data(DiversityPlotSpec(predictor: .population, locus: "Gone"))
        guard case .unavailable(let reason) = plot.content else {
            Issue.record("expected unavailable")
            return
        }
        #expect(reason.contains("Gone"))
    }

    @Test func missingGroupIsReportedNotDrawn() throws {
        let plot = try data(DiversityPlotSpec(predictor: .locus, sample: .group(name: "Gone")))
        guard case .unavailable(let reason) = plot.content else {
            Issue.record("expected unavailable")
            return
        }
        #expect(reason.contains("Gone"))
    }

    @Test func coordinatesPredictorNeedsCoordinates() throws {
        let csv = """
            Population,L1
            A,1:2
            """
        let dataset = try Self.dataset(csv)
        let options = DiversityPlotOptions(dataset: dataset)
        #expect(!options.predictors.contains(.latitude))
        let plot = DiversityPlotData(spec: DiversityPlotSpec(predictor: .latitude), dataset: dataset)
        guard case .unavailable = plot.content else {
            Issue.record("expected unavailable")
            return
        }
    }

    // MARK: - Study designs

    @Test func familyStatisticsUseOffspring() throws {
        let options = DiversityPlotOptions(dataset: try ExampleDataset.cornusFamilies.load())
        #expect(!options.families.isEmpty)
        #expect(options.predictors.contains(.family))
        #expect(options.primaryGroupsTitle == (options.populations.isEmpty ? "families" : "populations"))
    }

    @Test func exampleDataDrawsEveryPredictor() throws {
        let dataset = try ExampleDataset.arapatPopulations.load()
        let options = DiversityPlotOptions(dataset: dataset)
        #expect(!options.populations.isEmpty)
        for predictor in options.predictors {
            let plot = DiversityPlotData(spec: DiversityPlotSpec(predictor: predictor), dataset: dataset)
            if case .unavailable(let reason) = plot.content { Issue.record("\(predictor): \(reason)") }
        }
    }

    // MARK: - Normalization

    @Test func normalizedSpecsThatDrawTheSamePlotCompareEqual() {
        let first = DiversityPlotSpec(predictor: .population, unit: .family, style: .density, bins: 30,
                                      sample: .group(name: "A"))
        #expect(first.normalized == DiversityPlotSpec(predictor: .population))
        #expect(DiversityPlotSpec(style: .density, bins: 30).normalized == DiversityPlotSpec(style: .density))
        #expect(DiversityPlotSpec(locus: "L1").normalized.locus == nil)
    }

    // MARK: - Legends

    @Test func legendStatesHowValuesWereComputed() throws {
        let options = DiversityPlotOptions(dataset: try Self.dataset(Self.csv))
        let pooled = DiversityPlotSpec(response: .Ae, predictor: .locus).suggestedLegend(options: options)
        #expect(pooled == "Per-locus effective number of alleles (Ae), computed from all adults pooled.")
        let scatter = DiversityPlotSpec(response: .He, predictor: .latitude).suggestedLegend(options: options)
        #expect(scatter == "Expected heterozygosity (He) for each population, averaged across loci, "
                + "plotted against the population's mean latitude.")
        #expect(DiversityPlotSpec(response: .He, predictor: .latitude).suggestedTitle == "He by latitude")
    }
}
