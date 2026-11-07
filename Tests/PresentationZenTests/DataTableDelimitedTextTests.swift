//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DataTableDelimitedTextTests.swift
//  PresentationZenTests
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import TabularData
import Testing
@testable import PresentationZen

struct DataTableDelimitedTextTests {

    private static var awkward: DataTable {
        var frame = DataFrame()
        frame.append(column: Column(name: "population", contents: ["Big, \"old\" pop", "Tab\tbed"]))
        frame.append(column: Column(name: "He", contents: [1.0 / 3.0, 0.1 + 0.2]))
        return DataTable(frame: frame)
    }

    @Test func csvQuotesOnlyWhatNeedsIt() {
        #expect(Self.awkward.csvText == "population,He\n\"Big, \"\"old\"\" pop\",0.333333333333333\nTab\tbed,0.3\n")
    }

    @Test func tabSeparatedTextKeepsEachValueInItsCell() {
        #expect(Self.awkward.tabSeparatedText
                == "population\tHe\nBig, \"old\" pop\t0.333333333333333\nTab bed\t0.3\n")
    }

    @Test func missingAndNonFiniteValuesAreEmpty() {
        var frame = DataFrame()
        frame.append(column: Column(name: "x", contents: [1.0, nil, .nan] as [Double?]))
        #expect(DataTable(frame: frame).csvText == "x\n1\n\n\n")
    }

    @Test func datesAreISO8601() {
        var frame = DataFrame()
        frame.append(column: Column(name: "when", contents: [Date(timeIntervalSince1970: 0)] as [Date?]))
        #expect(DataTable(frame: frame).csvText == "when\n1970-01-01T00:00:00Z\n")
    }
}
