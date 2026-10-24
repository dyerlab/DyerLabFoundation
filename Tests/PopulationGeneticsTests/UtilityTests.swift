//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  UtilityTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2026.01.13.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Testing
@testable import PopulationGenetics

struct UtilityTests {

    // MARK: - FileIO Tests

    @Test func cSVToMatrixBasic() async throws {
        let csv = "A,B,C\n1,2,3\n4,5,6"
        let matrix = csvToMatrix(raw: csv)

        #expect(matrix.count == 3)
        #expect(matrix[0] == ["A", "B", "C"])
        #expect(matrix[1] == ["1", "2", "3"])
        #expect(matrix[2] == ["4", "5", "6"])
    }

    @Test func cSVToMatrixEmpty() async throws {
        let csv = ""
        let matrix = csvToMatrix(raw: csv)

        #expect(matrix.count == 1)
        #expect(matrix[0] == [""])
    }

    @Test func cSVToMatrixSingleRow() async throws {
        let csv = "A,B,C"
        let matrix = csvToMatrix(raw: csv)

        #expect(matrix.count == 1)
        #expect(matrix[0] == ["A", "B", "C"])
    }

    @Test func cSVToMatrixWithTrailingNewline() async throws {
        let csv = "A,B,C\n1,2,3\n"
        let matrix = csvToMatrix(raw: csv)

        #expect(matrix.count == 3)
        #expect(matrix[2] == [""]) // Trailing newline creates empty row
    }

    @Test func cSVToMatrixUnevenColumns() async throws {
        let csv = "A,B,C\n1,2\n3,4,5,6"
        let matrix = csvToMatrix(raw: csv)

        #expect(matrix.count == 3)
        #expect(matrix[0].count == 3)
        #expect(matrix[1].count == 2)
        #expect(matrix[2].count == 4)
    }

    @Test func cSVToMatrixWithSpaces() async throws {
        let csv = "A, B, C\n1, 2, 3"
        let matrix = csvToMatrix(raw: csv)

        #expect(matrix.count == 2)
        #expect(matrix[0] == ["A", " B", " C"]) // Spaces are preserved
        #expect(matrix[1] == ["1", " 2", " 3"])
    }

    @Test func cSVToMatrixWithEmptyCells() async throws {
        let csv = "A,,C\n,2,"
        let matrix = csvToMatrix(raw: csv)

        #expect(matrix.count == 2)
        #expect(matrix[0] == ["A", "", "C"])
        #expect(matrix[1] == ["", "2", ""])
    }

    // MARK: - DiversityType Tests

    @Test func diversityTypeLevelAllelic() async throws {
        #expect(DiversityType.A.level == .Allelic)
        #expect(DiversityType.A95.level == .Allelic)
        #expect(DiversityType.Ae.level == .Allelic)
    }

    @Test func diversityTypeLevelGenotypic() async throws {
        #expect(DiversityType.Ho.level == .Genotypic)
        #expect(DiversityType.He.level == .Genotypic)
        #expect(DiversityType.Ht.level == .Genotypic)
        #expect(DiversityType.Hi.level == .Genotypic)
        #expect(DiversityType.Hos.level == .Genotypic)
        #expect(DiversityType.Hes.level == .Genotypic)
        #expect(DiversityType.Pe.level == .Genotypic)
    }

    @Test func diversityTypeRawValues() async throws {
        #expect(DiversityType.A.rawValue == "A")
        #expect(DiversityType.A95.rawValue == "A95")
        #expect(DiversityType.Ae.rawValue == "Ae")
        #expect(DiversityType.Ho.rawValue == "Ho")
        #expect(DiversityType.He.rawValue == "He")
        #expect(DiversityType.Undefined.rawValue == "Undefined")
    }

    // MARK: - DiversityLevel Tests

    @Test func diversityLevelRawValues() async throws {
        #expect(DiversityLevel.Allelic.rawValue == "Allelic")
        #expect(DiversityLevel.Genotypic.rawValue == "Genotypic")
    }
}
