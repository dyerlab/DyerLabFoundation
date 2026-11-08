//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DiversityFormulaTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import PopulationGenetics

struct DiversityFormulaTests {

    @Test func aDistributionIsTildeOne() {
        #expect(DiversityPlotSpec().formula == "He ~ 1")
        #expect(DiversityPlotSpec(unit: .population).formula == "He ~ 1 | Population")
        #expect(DiversityPlotSpec(unit: .locusWithinFamily).formula == "He ~ 1 | Locus, Family")
    }

    @Test func predictorsAndConditionsAreNamed() {
        #expect(DiversityPlotSpec(response: .Ae, predictor: .population).formula == "Ae ~ Population")
        #expect(DiversityPlotSpec(predictor: .population, locus: "L01").formula == "He ~ Population | Locus: L01")
        #expect(DiversityPlotSpec(predictor: .locus, sample: .group(name: "Pop01")).formula == "He ~ Locus | Pop01")
        #expect(DiversityPlotSpec(predictor: .sampleSize).formula == "He ~ n")
    }

    @Test func unusedParametersAreLeftOut() {
        // A locus means nothing to a by-locus plot, so the formula ignores it as the plot does.
        #expect(DiversityPlotSpec(predictor: .locus, locus: "L01").formula == "He ~ Locus")
    }
}
