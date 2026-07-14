//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Adapted from PopulationGenetics' PairwiseExportTests.swift, which
//  exercised DataTable(pairwise:) via its own domain markers (PhiSTKind,
//  SpatialMatrix). Local test-only markers stand in here since the join
//  logic under test doesn't depend on what the measures mean. Column names
//  updated: StratumA/StratumB -> GroupA/GroupB (the "Stratum" naming was
//  domain-specific and didn't belong at this layer).
//

import Foundation
import Testing
@testable import Matrix
@testable import PresentationZen

private enum TestKindOne: PairwiseMeasure {
    static let columnName = "KindOne"
}

private enum TestKindTwo: PairwiseMeasure {
    static let columnName = "KindTwo"
}

struct DataTablePairwiseMatrixTests {

    @Test func dataTableJoinsMultiplePairwiseMatricesIntoOneLongFormatTable() async throws {
        var one = DistanceMatrix<TestKindOne>(groupNames: ["A", "B", "C"])
        one[0, 1] = 0.1
        one[0, 2] = 0.2
        one[1, 2] = 0.3

        var two = DistanceMatrix<TestKindTwo>(groupNames: ["A", "B", "C"])
        two[0, 1] = 10.0
        two[0, 2] = 20.0
        two[1, 2] = 30.0

        let table = DataTable(pairwise: [one, two])
        #expect(table.rowCount == 3)
        #expect(Set(table.columnNames) == ["GroupA", "GroupB", "KindOne", "KindTwo"])
    }

    @Test func dataTableJoinPreservesRowOrderAndValues() async throws {
        var one = DistanceMatrix<TestKindOne>(groupNames: ["A", "B", "C"])
        one[0, 1] = 0.1
        one[0, 2] = 0.2
        one[1, 2] = 0.3

        let table = DataTable(pairwise: [one])
        let groupA = Array(table.frame["GroupA", String.self]).map { $0! }
        let groupB = Array(table.frame["GroupB", String.self]).map { $0! }
        let values = Array(table.frame["KindOne", Double.self]).map { $0! }
        #expect(groupA == ["A", "A", "B"])
        #expect(groupB == ["B", "C", "C"])
        #expect(values == [0.1, 0.2, 0.3])
    }
}
