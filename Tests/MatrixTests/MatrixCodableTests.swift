//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//
//  Created by Rodney Dyer on 4/23/26.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import Matrix

// MARK: - Matrix Codable Tests

struct MatrixCodableTests {

    @Test func encodeDecodeRoundtrip() throws {
        let original = Matrix(3, 3, Vector([1, 2, 3, 4, 5, 6, 7, 8, 9]))
        original.rowNames = ["r1", "r2", "r3"]
        original.colNames = ["c1", "c2", "c3"]

        let data     = try JSONEncoder().encode(original)
        let decoded  = try JSONDecoder().decode(Matrix.self, from: data)

        #expect(decoded == original)
        #expect(decoded.rowNames == original.rowNames)
        #expect(decoded.colNames == original.colNames)
    }

    @Test func encodeDecodePreservesValues() throws {
        let original = Matrix(2, 2, Vector([0.9, 0.1, 0.2, 0.8]))
        let data     = try JSONEncoder().encode(original)
        let decoded  = try JSONDecoder().decode(Matrix.self, from: data)

        #expect(decoded[0, 0] == 0.9)
        #expect(decoded[0, 1] == 0.1)
        #expect(decoded[1, 0] == 0.2)
        #expect(decoded[1, 1] == 0.8)
    }

    @Test func encodeDecodeEmptyNamesSurvive() throws {
        let original = Matrix(2, 2)
        let data     = try JSONEncoder().encode(original)
        let decoded  = try JSONDecoder().decode(Matrix.self, from: data)

        #expect(decoded.rows == 2)
        #expect(decoded.cols == 2)
        #expect(decoded.rowNames == ["", ""])
        #expect(decoded.colNames == ["", ""])
    }

    @Test func nestedArrayRoundtrip() {
        let nested = [[1.0, 2.0], [3.0, 4.0]]
        let matrix = Matrix(nested: nested, rowNames: ["A", "B"], colNames: ["X", "Y"])
        let back   = matrix.nestedArray

        #expect(back == nested)
        #expect(matrix.rowNames == ["A", "B"])
        #expect(matrix.colNames == ["X", "Y"])
    }

    @Test func nestedArrayFromMatrix() {
        let mat = Matrix(3, 3, 1.0...9.0)
        let nested = mat.nestedArray

        #expect(nested.count == 3)
        #expect(nested[0].count == 3)
        #expect(nested[0][0] == mat[0, 0])
        #expect(nested[2][2] == mat[2, 2])
    }

}
