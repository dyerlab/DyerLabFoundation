//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  NullDensityPlotTests.swift
//  PresentationZenTests
//
//  Created by Rodney Dyer on 2026.11.09.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix
import Testing
@testable import PresentationZen

@MainActor
struct NullDensityPlotTests {

    @Test func theAxisSpansThePermutedAndObservedValuesAndNoMore() {
        // Fewer permuted values than density points, and an observed value far beyond them: the case whose axis
        // once ran to 10^178 when `+` added the arrays instead of joining them.
        let values = (0..<99).map { Double($0 % 20) / 100 - 0.1 }
        let plot = NullDensityPlot(NullDistributionResult(analysisType: AnalysisTag("test"), observed: 0.82,
                                                          values: values), statisticLabel: "Mantel r")
        let domain = plot.xDomain
        #expect(domain.contains(0.82) && domain.contains(-0.1))
        #expect(domain.lowerBound > -1 && domain.upperBound < 1.1)
    }
}
