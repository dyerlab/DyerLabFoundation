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
//  Adapted from PopulationGenetics' GeneticDistanceTests.swift structural
//  coverage (init-to-zero, diagonal, symmetry, add/subtract, dense) —
//  originally written against GeneticDistanceMatrix, now against the shared
//  SymmetricUpperTriangle<Double> storage both DistanceMatrix<Kind> and
//  GeneticDistanceMatrix build on.
//

import Foundation
import Testing
@testable import Matrix

struct SymmetricUpperTriangleTests {

    @Test func matrixInitializesToZero() async throws {
        let m = SymmetricUpperTriangle<Double>(count: 5)
        for i in 0..<5 {
            for j in 0..<5 {
                #expect(m[i, j] == 0.0)
            }
        }
    }

    @Test func diagonalAlwaysZeroAfterWrite() async throws {
        var m = SymmetricUpperTriangle<Double>(count: 3)
        m[0, 1] = 5.0
        m[0, 2] = 3.0
        for i in 0..<3 {
            #expect(m[i, i] == 0.0)
        }
    }

    @Test func subscriptIsSymmetric() async throws {
        var m = SymmetricUpperTriangle<Double>(count: 4)
        m[0, 3] = 7.5
        m[1, 2] = 2.0
        #expect(m[3, 0] == 7.5)
        #expect(m[2, 1] == 2.0)
    }

    @Test func addAccumulatesValues() async throws {
        var a = SymmetricUpperTriangle<Double>(count: 3)
        a[0, 1] = 1.0; a[0, 2] = 4.0; a[1, 2] = 1.0
        var b = SymmetricUpperTriangle<Double>(count: 3)
        b[0, 1] = 3.0; b[0, 2] = 1.0; b[1, 2] = 1.0
        a.add(b)
        #expect(a[0, 1] == 4.0)
        #expect(a[0, 2] == 5.0)
        #expect(a[1, 2] == 2.0)
    }

    @Test func subtractUndoesAdd() async throws {
        var total = SymmetricUpperTriangle<Double>(count: 3)
        total[0, 1] = 4.0; total[0, 2] = 5.0; total[1, 2] = 2.0
        var part = SymmetricUpperTriangle<Double>(count: 3)
        part[0, 1] = 1.0; part[0, 2] = 4.0; part[1, 2] = 1.0
        total.subtract(part)
        #expect(total[0, 1] == 3.0)
        #expect(total[0, 2] == 1.0)
        #expect(total[1, 2] == 1.0)
    }

    @Test func denseIsSymmetricWithZeroDiagonal() async throws {
        var m = SymmetricUpperTriangle<Double>(count: 3)
        m[0, 1] = 2.0; m[0, 2] = 5.0; m[1, 2] = 3.0
        let d = m.dense()
        #expect(d.count == 3)
        #expect(d[0][1] == 2.0 && d[1][0] == 2.0)
        #expect(d[0][2] == 5.0 && d[2][0] == 5.0)
        #expect(d[1][2] == 3.0 && d[2][1] == 3.0)
        for i in 0..<3 { #expect(d[i][i] == 0.0) }
    }

    @Test func equalityReflexive() async throws {
        var m = SymmetricUpperTriangle<Double>(count: 3)
        m[0, 1] = 2.0
        #expect(m == m)
    }

    @Test func submatrixGathersScatteredIndices() async throws {
        var m = SymmetricUpperTriangle<Double>(count: 4)
        m[0, 1] = 1.0; m[0, 2] = 2.0; m[0, 3] = 3.0
        m[1, 2] = 4.0; m[1, 3] = 5.0; m[2, 3] = 6.0

        // Gather indices [3, 1] (reversed, non-contiguous) into a 2x2 result.
        let sub = m.submatrix(indices: [3, 1])
        #expect(sub.count == 2)
        #expect(sub[0, 1] == m[3, 1])
    }
}
