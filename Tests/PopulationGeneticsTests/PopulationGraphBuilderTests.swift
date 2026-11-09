//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopulationGraphBuilderTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2026.10.24.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
import PresentationZen
@testable import PopulationGenetics

struct PopulationGraphBuilderTests {

    private func exampleDataset() throws -> ImportedDataset {
        try TestData.dataset(TestData.exampleCSV())
    }

    @Test func everyExamplePopulationIsEligible() throws {
        let eligibility = PopulationGraphBuilder.Eligibility(dataset: try exampleDataset())
        #expect(eligibility.included.count == 25)
        #expect(eligibility.excluded.isEmpty)
        #expect(eligibility.canEstimate)
    }

    @Test func populationsUnderThreeAreExcluded() throws {
        var dataset = try exampleDataset()
        dataset.setPopulationName("Tiny", at: 0)
        dataset.setPopulationName("Tiny", at: 1)
        let eligibility = PopulationGraphBuilder.Eligibility(dataset: dataset)
        #expect(eligibility.excluded.map(\.name) == ["Tiny"])
        #expect(eligibility.excluded.first?.count == 2)
        #expect(eligibility.included.count == 25)
    }

    @Test func estimatesOneNodePerPopulationAtItsCentroid() throws {
        let dataset = try exampleDataset()
        let graph = try #require(PopulationGraphBuilder.estimate(from: dataset))
        #expect(graph.graph.nodes.count == 25)
        #expect(!graph.graph.edges.isEmpty)
        let pop01 = try #require(graph.graph.nodes.first { $0.name == "Pop01" })
        #expect(abs(try #require(pop01.longitude) - TestData.pop01Longitude) < 1e-6)
        #expect(abs(try #require(pop01.latitude) - TestData.pop01Latitude) < 1e-6)
        #expect(graph.nodeStrata[pop01.id]?.last?.name == "Pop01")
        #expect(graph.loci.count == 20)
    }

    @Test func excludedPopulationsAreNotNodes() throws {
        var dataset = try exampleDataset()
        dataset.setPopulationName("Tiny", at: 0)
        let graph = try #require(PopulationGraphBuilder.estimate(from: dataset))
        #expect(!graph.graph.nodes.contains { $0.name == "Tiny" })
    }

    @Test func genotypeEditsMakeTheGraphStaleButCoordinateEditsDoNot() throws {
        var dataset = try exampleDataset()
        let graph = try #require(PopulationGraphBuilder.estimate(from: dataset))
        #expect(!PopulationGraphBuilder.isStale(graph, for: dataset))

        dataset.setLatitude(38.5, at: 0)
        #expect(!PopulationGraphBuilder.isStale(graph, for: dataset))

        let edited = dataset.setAlleles(("07", "07"), at: 0, locus: 0)
        #expect(edited)
        #expect(PopulationGraphBuilder.isStale(graph, for: dataset))
    }

    @Test func csvWithoutPopulationColumnHasNoPopulations() throws {
        let csv = "Longitude,Latitude,L01,L02\n-80.1,38.4,01:02,01:01\n-80.2,38.5,02:02,01:02\n"
        let dataset = try TestData.dataset(csv)
        #expect(dataset.matrix.individualCount == 2)
        #expect(dataset.matrix.locusCount == 2)
        #expect(!dataset.hasPopulations)
        #expect(try exampleDataset().hasPopulations)
    }

    // MARK: - Levels

    @Test func nodesCanBeTheStrataOfAnyLevel() throws {
        let dataset = try ExampleDataset.arapatPopulations.load()
        #expect(PopulationGraphBuilder.levels(in: dataset) == ["Species", "Cluster", "Population"])
        let innermost = try #require(PopulationGraphBuilder.estimate(from: dataset))
        #expect(PopulationGraphBuilder.level(of: innermost) == "Population")

        let clusters = PopulationGraphBuilder.Eligibility(dataset: dataset, level: "Cluster")
        let graph = try #require(PopulationGraphBuilder.estimate(from: dataset, level: "Cluster"))
        #expect(graph.graph.nodes.count == clusters.included.count)
        #expect(graph.graph.nodes.count < innermost.graph.nodes.count)
        #expect(PopulationGraphBuilder.level(of: graph) == "Cluster")
        #expect(graph.nodeStrata.values.allSatisfy { $0.map(\.level) == ["Species", "Cluster"] })
        #expect(graph.graph.nodes.allSatisfy { $0.latitude != nil && $0.longitude != nil })
        #expect(!PopulationGraphBuilder.isStale(graph, for: dataset))
    }

    @Test func onlyAdultsAreNodesMembers() throws {
        let dataset = try ExampleDataset.cornusFamilies.load()
        let adults = Set(dataset.adultOrdinals)
        let counted = PopulationGraphBuilder.Eligibility(dataset: dataset)
        let total = (counted.included + counted.excluded).map(\.count).reduce(0, +)
        #expect(total <= adults.count && adults.count < dataset.matrix.individualCount)
    }

    @Test func pollenPoolsAreTheNodesOfAPollinationGraph() throws {
        let dataset = try TestData.dataset(TestData.pechinataCSV())
        let level = PopulationGraphBuilder.pollenPoolLevel
        #expect(PopulationGraphBuilder.levels(in: dataset).last == level)
        let eligibility = PopulationGraphBuilder.Eligibility(dataset: dataset, level: level)
        #expect(eligibility.canEstimate)
        let graph = try #require(PopulationGraphBuilder.estimate(from: dataset, level: level))
        let families = Set(dataset.familiesWithOffspring.map(\.id))
        #expect(graph.graph.nodes.count > 2 && graph.graph.nodes.allSatisfy { families.contains($0.name) })
        #expect(PopulationGraphBuilder.level(of: graph) == level && !graph.graph.edges.isEmpty)
        #expect(graph.nodeStrata.values.allSatisfy { $0.map(\.level) == ["Treatment", "Cluster", level] })
        #expect(!PopulationGraphBuilder.isStale(graph, for: dataset))

        // An offspring's genotype is part of its pollen pool, so editing it makes the graph stale.
        var edited = dataset
        let child = try #require(dataset.familiesWithOffspring.first?.offspring.first)
        let changed = edited.setAlleles(("9", "9"), at: child, locus: 0)
        #expect(changed)
        #expect(PopulationGraphBuilder.isStale(graph, for: edited))
    }
}
