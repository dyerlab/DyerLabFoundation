//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AllelePairTextTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Testing
@testable import PopulationGenetics

struct AllelePairTextTests {

    @Test func splitsAGenotype() {
        #expect(AllelePairText(value: "01:02", separator: ":") == AllelePairText(left: "01", right: "02"))
    }

    @Test func anythingElseSplitsToEmptyFields() {
        #expect(AllelePairText(value: "", separator: ":") == AllelePairText())
        #expect(AllelePairText(value: "01", separator: ":") == AllelePairText())
        #expect(AllelePairText(value: "1:2:3", separator: ":") == AllelePairText())
    }

    @Test func joinsTrimmedAlleles() {
        #expect(AllelePairText(left: " 1 ", right: "2").value(separator: ":") == "1:2")
        #expect(AllelePairText(left: "1", right: "").value(separator: "/") == "1/")
    }

    @Test func bothEmptyIsMissing() {
        #expect(AllelePairText(left: " ", right: "").value(separator: ":") == "")
    }
}
