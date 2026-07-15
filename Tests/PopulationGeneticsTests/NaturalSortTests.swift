//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  NaturalSortTests.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//

import Testing
import Matrix
@testable import PopulationGenetics

struct NaturalSortTests {

    // MARK: - naturalCompare / naturalSorted

    @Test func sortsAraptusPopulationCodesNumericallyThenAlphabetically() async throws {
        // Real values from ExampleData/arapat.csv's `Population` column: a mix of purely
        // numeric site codes and short alphabetic ones. Lexicographic sort would put
        // "12" before "2" and "160" before "9"; natural sort must not.
        let values = [
            "88", "9", "84", "175", "177", "173", "171", "89", "159", "SFr", "160", "162",
            "12", "161", "93", "165", "169", "58", "166", "64", "168", "51", "Const", "77",
            "164", "75", "163", "ESan", "153", "48", "156", "157", "73", "Aqu",
        ]

        let expected = [
            "9", "12", "48", "51", "58", "64", "73", "75", "77", "84", "88", "89", "93",
            "153", "156", "157", "159", "160", "161", "162", "163", "164", "165", "166",
            "168", "169", "171", "173", "175", "177", "Aqu", "Const", "ESan", "SFr",
        ]

        #expect(values.naturalSorted() == expected)
    }

    @Test func sortsDoubleDigitCodesBeforeTripleDigitCodes() async throws {
        // The classic natural-sort failure case: "1","2",...,"10","11",...,"100","101"
        // must stay in numeric order, not "1","10","100","101","11",...,"2".
        let values = ["100", "101", "11", "10", "2", "1"]
        #expect(values.naturalSorted() == ["1", "2", "10", "11", "100", "101"])
    }

    @Test func sortsContigNamesNumerically() async throws {
        // Real contig names from ExampleData/phylog.012.pos.
        let values = ["dDocent_Contig_16", "dDocent_Contig_9", "dDocent_Contig_105", "dDocent_Contig_2"]
        let expected = ["dDocent_Contig_2", "dDocent_Contig_9", "dDocent_Contig_16", "dDocent_Contig_105"]
        #expect(values.naturalSorted() == expected)
    }

    @Test func naturalSortedByKeyPathSortsStructsByStringField() async throws {
        struct Named { let name: String }
        let values = [Named(name: "88"), Named(name: "9"), Named(name: "12")]
        let sorted = values.naturalSorted(by: \.name)
        #expect(sorted.map(\.name) == ["9", "12", "88"])
    }
}
