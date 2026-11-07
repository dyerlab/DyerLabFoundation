//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  FamilyReportTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2026.11.01.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
import PresentationZen
@testable import PopulationGenetics

struct FamilyReportTests {

    /// Mother 1:2 at A; offspring resolve, match her heterozygote, conflict, and miss.
    private static let csv = """
        ID,Offspring,A
        F1,0,1:2
        F1,1,1:3
        F1,2,1:2
        F1,3,5:6
        F1,4,
        F2,1,1:1
        """

    private func dataset() throws -> ImportedDataset {
        try TestData.dataset(Self.csv)
    }

    @Test func paternalTextIsHaploidUnlessAmbiguousOrImpossible() throws {
        let dataset = try dataset()
        #expect(dataset.paternalText(offspring: 1, mother: 0, locus: 0).text == "3")
        #expect(dataset.paternalText(offspring: 2, mother: 0, locus: 0).text == "1:2")
        #expect(dataset.paternalText(offspring: 3, mother: 0, locus: 0).text == "5:6")
        #expect(dataset.paternalText(offspring: 4, mother: 0, locus: 0).text == "")
    }

    @Test func reportCountsEachOutcomeAndListsMismatches() throws {
        let dataset = try dataset()
        let report = FamilyReport(dataset: dataset, family: dataset.parentage.families[0])
        #expect(report.resolved == 1)
        #expect(report.ambiguous == 1)
        #expect(report.missing == 1)
        #expect(report.mismatches == [FamilyReport.Mismatch(offspring: 3, locus: 0)])
    }

    @Test func familyWithoutMotherHasNothingToRecover() throws {
        let dataset = try dataset()
        let family = dataset.parentage.families[1]
        #expect(family.mother == nil)
        let report = FamilyReport(dataset: dataset, family: family)
        #expect(report.resolved + report.ambiguous + report.missing == 0)
        #expect(report.mismatches.isEmpty)
    }

    @Test func exampleOffspringListsOnlyFamiliesWithMotherAndOffspring() throws {
        let csv = try TestData.offspringCSV()
        #expect(try GenotypeTableLayout(csv: csv).isParentOffspring)
        let dataset = try TestData.dataset(csv)
        #expect(dataset.matrix.individualCount == 62)
        #expect(dataset.parentage.families.count == 22)
        #expect(dataset.familiesWithOffspring.map(\.id) == ["468", "474"])
        #expect(dataset.familiesWithOffspring.allSatisfy { $0.offspring.count == 20 })
    }

    @Test func adultsAreTheMothersInParentOffspringData() throws {
        let dataset = try TestData.dataset(TestData.offspringCSV())
        #expect(dataset.adultOrdinals.count == 22)
        #expect(dataset.adultOrdinals.allSatisfy { ordinal in
            dataset.parentage.families.contains { $0.mother == ordinal }
        })
        #expect(PopulationClusters(dataset: dataset, ordinals: dataset.adultOrdinals).individualCount == 22)
    }

    @Test func adultsAreEveryoneInAdultData() throws {
        let dataset = try TestData.dataset(TestData.exampleCSV())
        #expect(dataset.adultOrdinals == Array(0..<dataset.matrix.individualCount))
    }
}
