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
//  Local test-only PairwiseMeasure conformers stand in for what
//  PopulationGenetics tested with its own domain markers (PhiSTKind,
//  GreatCircleKind) — the type-isolation property under test doesn't
//  depend on what those markers mean, only that they're distinct types.
//

import Foundation
import Testing
@testable import Matrix

private enum TestMeasureA: PairwiseMeasure {
    static let columnName = "MeasureA"
}

private enum TestMeasureB: PairwiseMeasure {
    static let columnName = "MeasureB"
}

struct DistanceMatrixTests {

    @Test func initializesToZero() async throws {
        let m = DistanceMatrix<TestMeasureA>(groupNames: ["X", "Y", "Z"])
        #expect(m[0, 1] == 0.0)
        #expect(m["X", "Y"] == 0.0)
    }

    @Test func subscriptByNameMatchesSubscriptByIndex() async throws {
        var m = DistanceMatrix<TestMeasureA>(groupNames: ["X", "Y", "Z"])
        m[0, 2] = 4.5
        #expect(m["X", "Z"] == 4.5)
        #expect(m["Z", "X"] == 4.5)
    }

    @Test func subscriptByNameReturnsNilForUnknownGroup() async throws {
        let m = DistanceMatrix<TestMeasureA>(groupNames: ["X", "Y"])
        #expect(m["X", "Nope"] == nil)
    }

    @Test func columnNameForwardsFromKind() async throws {
        let m = DistanceMatrix<TestMeasureA>(groupNames: ["X", "Y"])
        #expect(m.columnName == "MeasureA")
    }

    @Test func distinctKindsAreDistinctTypes() async throws {
        // Compile-time check as much as runtime: DistanceMatrix<TestMeasureA>
        // and DistanceMatrix<TestMeasureB> are different instantiations and
        // cannot be used interchangeably — this test exists to fail to
        // *compile* (not to fail at runtime) if that isolation is lost.
        let a = DistanceMatrix<TestMeasureA>(groupNames: ["X", "Y"])
        let b = DistanceMatrix<TestMeasureB>(groupNames: ["X", "Y"])
        #expect(a.columnName != b.columnName)
    }

    @Test func denseIsSymmetricWithZeroDiagonal() async throws {
        var m = DistanceMatrix<TestMeasureA>(groupNames: ["A", "B", "C"])
        m[0, 1] = 2.0; m[0, 2] = 5.0; m[1, 2] = 3.0
        let d = m.dense()
        #expect(d.count == 3)
        #expect(d[0][1] == 2.0 && d[1][0] == 2.0)
        for i in 0..<3 { #expect(d[i][i] == 0.0) }
    }

    @Test func conformsToPairwiseMatrixExistential() async throws {
        var a = DistanceMatrix<TestMeasureA>(groupNames: ["X", "Y"])
        a[0, 1] = 1.0
        let erased: any PairwiseMatrix = a
        #expect(erased.groupNames == ["X", "Y"])
        #expect(erased.columnName == "MeasureA")
        #expect(erased[0, 1] == 1.0)
    }
}
