//
//  PairwiseExportTests.swift
//  PopulationGenetics
//
//  Tests for SpatialMatrix, pairwiseGreatCircleDistance, and
//  DataTable(pairwise:) — the DistanceMatrix<Kind> umbrella's export path.
//

import Testing
import CoreLocation
import Matrix
import PresentationZen
@testable import PopulationGenetics

struct PairwiseExportTests {

    @Test func pairwiseGreatCircleDistanceIsSymmetricAndZeroOnDiagonal() async throws {
        let locations: [String: CLLocationCoordinate2D] = [
            "Richmond": CLLocationCoordinate2D(latitude: 37.5407, longitude: -77.4360),
            "Roanoke": CLLocationCoordinate2D(latitude: 37.2710, longitude: -79.9414),
            "NorfolkVA": CLLocationCoordinate2D(latitude: 36.8508, longitude: -76.2859),
        ]
        let result = pairwiseGreatCircleDistance(locations: locations)
        #expect(result.groupNames == ["NorfolkVA", "Richmond", "Roanoke"])
        #expect(result[0, 0] == 0)
        #expect(result[0, 1] == result[1, 0])
        // Richmond-Roanoke is a real ~250km drive; great-circle should be in that ballpark.
        let richmondRoanoke = result["Richmond", "Roanoke"]!
        #expect(richmondRoanoke > 150 && richmondRoanoke < 300)
    }

    @Test func pairwiseGreatCircleDistanceOmitsUnlocatedGroups() async throws {
        let result = pairwiseGreatCircleDistance(locations: [
            "OnlyOne": CLLocationCoordinate2D(latitude: 0, longitude: 0),
        ])
        #expect(result.groupNames == ["OnlyOne"])
    }

    @Test func phiSTAndSpatialAreDistinctTypes() async throws {
        // Compile-time check as much as runtime: PhiSTMatrix and SpatialMatrix
        // are different instantiations of DistanceMatrix<Kind> and cannot be
        // used interchangeably — this test exists to fail to *compile* (not
        // to fail at runtime) if that type isolation is ever accidentally lost.
        let phi = PhiSTMatrix(groupNames: ["A", "B"])
        let spatial = SpatialMatrix(groupNames: ["A", "B"])
        #expect(phi.columnName == "PhiST")
        #expect(spatial.columnName == "GreatCircleDistance")
    }

    @Test func dataTableJoinsMultiplePairwiseMatricesIntoOneLongFormatTable() async throws {
        var phi = PhiSTMatrix(groupNames: ["A", "B", "C"])
        phi[0, 1] = 0.1
        phi[0, 2] = 0.2
        phi[1, 2] = 0.3

        var spatial = SpatialMatrix(groupNames: ["A", "B", "C"])
        spatial[0, 1] = 10.0
        spatial[0, 2] = 20.0
        spatial[1, 2] = 30.0

        let table = DataTable(pairwise: [phi, spatial])
        #expect(table.rowCount == 3)
        #expect(Set(table.columnNames) == ["GroupA", "GroupB", "PhiST", "GreatCircleDistance"])
    }

    @Test func dataTableJoinPreservesRowOrderAndValues() async throws {
        var phi = PhiSTMatrix(groupNames: ["A", "B", "C"])
        phi[0, 1] = 0.1
        phi[0, 2] = 0.2
        phi[1, 2] = 0.3

        let table = DataTable(pairwise: [phi])
        let groupA = Array(table.frame["GroupA", String.self]).map { $0! }
        let groupB = Array(table.frame["GroupB", String.self]).map { $0! }
        let values = Array(table.frame["PhiST", Double.self]).map { $0! }
        #expect(groupA == ["A", "A", "B"])
        #expect(groupB == ["B", "C", "C"])
        #expect(values == [0.1, 0.2, 0.3])
    }
}
