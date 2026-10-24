//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StratumTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2025.06.05.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import PopulationGenetics

@MainActor
struct StratumTests {

    @Test func frequencyExtraction() async throws {

        let dataStore = PopulationGeneticsPreviewData.shared.dataStore
        let stratum = dataStore.getStratum(named: "102", within: "Population")

        #expect(stratum != nil)
        #expect(dataStore.getIndividuals(for: stratum!).count == 8)

        let LTRS = dataStore.getLocus(for: stratum!, named: "LTRS")
        #expect(LTRS != nil)

        let genotypes = dataStore.getGenotypes(for: stratum!, locusName: "LTRS")
        #expect(genotypes.count == 8)

        let fLTRS = dataStore.frequenciesForLocus(for: stratum!, locus: LTRS!)
        #expect(fLTRS.N == 2.0 * Double(genotypes.count))

    }

}
