//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StratumReportTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2026.11.09.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import PopulationGenetics

struct StratumReportTests {

    @Test func aPopulationHoldsItsIndividualsAndTheirDiversity() throws {
        let dataset = try TestData.dataset(TestData.exampleCSV())
        let names = StratumReport.strata(of: "Population", in: dataset)
        #expect(names.count == 25 && names.first == "Pop01")
        let report = StratumReport(dataset: dataset, level: "Population", name: "Pop01")
        #expect(report.ordinals.count == 100 && report.adults == report.ordinals && report.offspringCount == 0)
        #expect(report.parents.isEmpty && report.locatedCount == 100)
        #expect(abs(try #require(report.latitude) - TestData.pop01Latitude) < 0.01)
        #expect(report.loci.count == 20)

        // Each locus matches the allele counts over the same individuals.
        let first = try #require(report.loci.first)
        let frequencies = dataset.matrix.frequencies(atLocus: 0, over: report.ordinals)
        #expect(first.genotyped == Int(frequencies.numGenos))
        #expect(first.he == frequencies.He && first.ho == frequencies.Ho)
    }

    @Test func multilocusFIsARatioOfSums() throws {
        let dataset = try TestData.dataset(TestData.exampleCSV())
        let report = StratumReport(dataset: dataset, level: "Population", name: "Pop02")
        let typed = report.loci.filter { $0.genotyped > 0 }
        let ho = typed.compactMap(\.ho).reduce(0, +), he = typed.compactMap(\.he).reduce(0, +)
        let f = try #require(report.multilocus.f)
        #expect(abs(f - (1 - ho / he)) < 1e-12)
    }

    @Test func offspringAreCountedButLeftOutOfDiversity() throws {
        let dataset = try TestData.dataset(TestData.pechinataCSV())
        let clusters = StratumReport.strata(of: "Cluster", in: dataset)
        #expect(clusters.count == 15)
        let report = StratumReport(dataset: dataset, level: "Cluster", name: try #require(clusters.first))
        #expect(report.parents.count == 1 && report.offspringCount > 0)
        let mothers = Set(dataset.adultOrdinals)
        #expect(report.adults.allSatisfy(mothers.contains))
        #expect(report.loci.allSatisfy { $0.genotyped <= report.adults.count })
    }
}
