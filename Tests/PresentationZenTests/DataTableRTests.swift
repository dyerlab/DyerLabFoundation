//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DataTableRTests.swift
//  PresentationZenTests
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import TabularData
import Testing
@testable import PresentationZen

struct DataTableRTests {

    private func table(_ build: (inout DataFrame) -> Void) -> DataTable {
        var frame = DataFrame()
        build(&frame)
        return DataTable(frame: frame)
    }

    @Test func columnsKeepTheirOrderAndTypes() {
        let table = table {
            $0.append(column: Column(name: "group", contents: ["A", "B"]))
            $0.append(column: Column(name: "He", contents: [0.4375, 0.0]))
        }
        #expect(table.toR() == """
            tibble(
              group = c( "A", "B" ),
              He = c( 0.4375, 0 )
            )
            """)
    }

    @Test func digitsAreChosenByTheCaller() {
        let table = DataTable(vector: [1.0 / 3.0])
        #expect(table.toR().contains("c( 0.333333333333333 )"))
        #expect(table.toR(significantDigits: 6).contains("c( 0.333333 )"))
    }

    @Test func missingAndNonFiniteValuesUseRsConstants() {
        let table = table {
            $0.append(column: Column(name: "x", contents: [1.0, nil, .nan, .infinity, -.infinity] as [Double?]))
            $0.append(column: Column(name: "label", contents: ["a", nil, "c", "d", "e"] as [String?]))
        }
        let code = table.toR()
        #expect(code.contains("x = c( 1, NA, NaN, Inf, -Inf )"))
        #expect(code.contains("label = c( \"a\", NA, \"c\", \"d\", \"e\" )"))
    }

    @Test func awkwardTextIsEscapedAndAwkwardNamesAreQuoted() {
        let table = table {
            $0.append(column: Column(name: "Site name", contents: ["Says \"hi\"\nC:\\x"]))
            $0.append(column: Column(name: "if", contents: [1.0]))
            $0.append(column: Column(name: "2nd", contents: [2.0]))
            $0.append(column: Column(name: ".ok_1", contents: [3.0]))
        }
        let code = table.toR()
        #expect(code.contains(#"`Site name` = c( "Says \"hi\" C:\\x" )"#))
        #expect(code.contains("`if` = c( 1 )"))
        #expect(code.contains("`2nd` = c( 2 )"))
        #expect(code.contains(".ok_1 = c( 3 )"))
    }

    @Test func datesBecomeUTCTimes() {
        let table = table {
            $0.append(column: Column(name: "when", contents: [Date(timeIntervalSince1970: 0), nil] as [Date?]))
        }
        // The options push the line past the width limit, so the vector wraps.
        #expect(table.toR() == """
            tibble(
              when = as.POSIXct( c(
                "1970-01-01T00:00:00Z", NA
              ), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ" )
            )
            """)
    }

    @Test func longColumnsWrap() {
        let table = DataTable(vector: (0..<200).map { Double($0) / 7 })
        let lines = table.toR(significantDigits: 6).split(separator: "\n")
        #expect(lines.count > 3)
        #expect(lines.allSatisfy { $0.count <= 80 })
    }

    @Test func tableWithNoColumnsIsAnEmptyTibble() {
        #expect(DataTable(frame: DataFrame()).toR() == "tibble()")
    }
}
