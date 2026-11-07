//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DiversityTypeTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import PopulationGenetics

struct DiversityTypeTests {

    @Test func statisticsReadFromAlleleCountsMatchTheirProperties() {
        var frequencies = AlleleFrequencies(alleleSlots: 3)
        frequencies.add(left: 1, right: 1)
        frequencies.add(left: 1, right: 2)
        #expect(DiversityType.A.value(of: frequencies) == frequencies.A)
        #expect(DiversityType.A95.value(of: frequencies) == frequencies.A95)
        #expect(DiversityType.Ae.value(of: frequencies) == frequencies.Ae)
        #expect(DiversityType.Ho.value(of: frequencies) == frequencies.Ho)
        #expect(DiversityType.He.value(of: frequencies) == frequencies.He)
    }

    @Test func onlyTheStatisticsOfOneLocusHaveValues() {
        var frequencies = AlleleFrequencies(alleleSlots: 3)
        frequencies.add(left: 1, right: 2)
        let computed = DiversityType.allCases.filter { $0.value(of: frequencies) != nil }
        #expect(Set(computed) == Set(DiversityType.frequencyStatistics))
    }

    @Test func nothingCountedHasNoValueRatherThanMaximalDiversity() {
        let empty = AlleleFrequencies(alleleSlots: 3)
        #expect(DiversityType.He.value(of: empty) == nil)
    }

    @Test func everyMetricHasALabelWithItsSymbol() {
        #expect(DiversityType.He.label == "Expected heterozygosity (He)")
        #expect(DiversityType.allCases.allSatisfy { $0.label.hasSuffix("(\($0.rawValue))") })
    }

    /// Saved plots are stored as this JSON, so these spellings must keep decoding.
    @Test func specsSavedBeforeTheMoveStillDecode() throws {
        let json = """
            {"bins":12,"predictor":"locus","response":"Ae","sample":{"group":{"name":"Pop01"}},\
            "style":"density","unit":"locusWithinPopulation"}
            """
        let spec = try JSONDecoder().decode(DiversityPlotSpec.self, from: Data(json.utf8))
        #expect(spec == DiversityPlotSpec(response: .Ae, predictor: .locus, unit: .locusWithinPopulation,
                                          style: .density, bins: 12, sample: .group(name: "Pop01")))
    }

    @Test func specsRoundTrip() throws {
        let spec = DiversityPlotSpec(response: .A95, predictor: .sampleSize, locus: "L1", sample: .meanWithinGroups)
        let decoded = try JSONDecoder().decode(DiversityPlotSpec.self, from: try JSONEncoder().encode(spec))
        #expect(decoded == spec)
    }
}
