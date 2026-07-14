//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2025 RJ Dyer.  All Rights Reserved.
//
//  UtilityTests.swift
// PopulationGenetics
//
//  Created by Claude Code on 1/13/26.
//

import Testing
@testable import PopulationGenetics

struct UtilityTests {

    // MARK: - FileIO Tests

    @Test func testCSVToMatrixBasic() async throws {
        let csv = "A,B,C\n1,2,3\n4,5,6"
        let matrix = csvToMatrix(raw: csv)

        #expect(matrix.count == 3)
        #expect(matrix[0] == ["A", "B", "C"])
        #expect(matrix[1] == ["1", "2", "3"])
        #expect(matrix[2] == ["4", "5", "6"])
    }

    @Test func testCSVToMatrixEmpty() async throws {
        let csv = ""
        let matrix = csvToMatrix(raw: csv)

        #expect(matrix.count == 1)
        #expect(matrix[0] == [""])
    }

    @Test func testCSVToMatrixSingleRow() async throws {
        let csv = "A,B,C"
        let matrix = csvToMatrix(raw: csv)

        #expect(matrix.count == 1)
        #expect(matrix[0] == ["A", "B", "C"])
    }

    @Test func testCSVToMatrixWithTrailingNewline() async throws {
        let csv = "A,B,C\n1,2,3\n"
        let matrix = csvToMatrix(raw: csv)

        #expect(matrix.count == 3)
        #expect(matrix[2] == [""]) // Trailing newline creates empty row
    }

    @Test func testCSVToMatrixUnevenColumns() async throws {
        let csv = "A,B,C\n1,2\n3,4,5,6"
        let matrix = csvToMatrix(raw: csv)

        #expect(matrix.count == 3)
        #expect(matrix[0].count == 3)
        #expect(matrix[1].count == 2)
        #expect(matrix[2].count == 4)
    }

    @Test func testCSVToMatrixWithSpaces() async throws {
        let csv = "A, B, C\n1, 2, 3"
        let matrix = csvToMatrix(raw: csv)

        #expect(matrix.count == 2)
        #expect(matrix[0] == ["A", " B", " C"]) // Spaces are preserved
        #expect(matrix[1] == ["1", " 2", " 3"])
    }

    @Test func testCSVToMatrixWithEmptyCells() async throws {
        let csv = "A,,C\n,2,"
        let matrix = csvToMatrix(raw: csv)

        #expect(matrix.count == 2)
        #expect(matrix[0] == ["A", "", "C"])
        #expect(matrix[1] == ["", "2", ""])
    }

    // MARK: - DiversityType Tests

    @Test func testDiversityTypeLevelAllelic() async throws {
        #expect(DiversityType.A.level == .Allelic)
        #expect(DiversityType.A95.level == .Allelic)
        #expect(DiversityType.Ae.level == .Allelic)
    }

    @Test func testDiversityTypeLevelGenotypic() async throws {
        #expect(DiversityType.Ho.level == .Genotypic)
        #expect(DiversityType.He.level == .Genotypic)
        #expect(DiversityType.Ht.level == .Genotypic)
        #expect(DiversityType.Hi.level == .Genotypic)
        #expect(DiversityType.Hos.level == .Genotypic)
        #expect(DiversityType.Hes.level == .Genotypic)
        #expect(DiversityType.Pe.level == .Genotypic)
    }

    @Test func testDiversityTypeRawValues() async throws {
        #expect(DiversityType.A.rawValue == "A")
        #expect(DiversityType.A95.rawValue == "A95")
        #expect(DiversityType.Ae.rawValue == "Ae")
        #expect(DiversityType.Ho.rawValue == "Ho")
        #expect(DiversityType.He.rawValue == "He")
        #expect(DiversityType.Undefined.rawValue == "Undefined")
    }

    // MARK: - DiversityLevel Tests

    @Test func testDiversityLevelRawValues() async throws {
        #expect(DiversityLevel.Allelic.rawValue == "Allelic")
        #expect(DiversityLevel.Genotypic.rawValue == "Genotypic")
    }
}
