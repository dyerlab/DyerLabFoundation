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
//  StratumTests.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 6/5/25.
//

import Foundation
import Testing
@testable import PopulationGenetics

struct StratumTests {

    @Test func testFrequencyExtraction() async throws {

        let dataStore = PopulationGeneticsPreviewData.shared.dataStore
        let stratum = dataStore.getStratum(named: "102", within: "Population")

        #expect( stratum != nil )
        #expect( dataStore.getIndividuals(for: stratum!).count == 8)

        let LTRS = dataStore.getLocus(for: stratum!, named: "LTRS")
        #expect( LTRS != nil )


        let genotypes = dataStore.getGenotypes(for: stratum!, locusName: "LTRS")
        print("\(genotypes)")
        #expect( genotypes.count == 8 )
        genotypes.forEach( { print("\($0)") } )


        let fLTRS = dataStore.frequenciesForLocus(for: stratum!, locus: LTRS! )
        print( "- \(fLTRS)")


    }

}
