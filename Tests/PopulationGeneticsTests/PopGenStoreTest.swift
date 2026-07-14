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
//  PopGenStoreTest.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 6/2/25.
//
//  Definitive end-to-end regression test against the real Data/arapat.csv
//  import (via PopulationGeneticsPreviewData). Counts below are recounted
//  directly from the file (see e.g. `tail -n +2 Data/arapat.csv | wc -l`),
//  not carried over from the old hardcoded-array preview dataset.
//

import Foundation
import Testing
@testable import PopulationGenetics

struct PopGenStoreTest {

    @Test func testDataStore() async throws {

        let dataStore = PopulationGeneticsPreviewData.shared.dataStore


        // Test for individuals
        let individuals = dataStore.fetchIndividuals()
        #expect(individuals.count == 363 )

        let firstID = individuals.first!.id
        let firstIndividual = dataStore.getIndividual(id: firstID)
        #expect( individuals.first?.id == firstIndividual?.id )


        // Test for Strata: 3 Species + 5 Clusters + 39 Populations = 47
        let strata = dataStore.getAllStrata()
        #expect( !strata.isEmpty, "Error in empty strata" )
        #expect( strata.count == 47 )

        let strata102 = strata.first(where: { $0.name == "102" })
        try #require( strata102 != nil )
        #expect( dataStore.getIndividuals(for: strata102!).count == 8 )

        let clusters = dataStore.getStrataWithin(level: "Cluster")
        #expect( clusters.count == 5 )
        #expect( clusters.compactMap{ $0.name}.sorted() == ["CBP-C", "NBP-C", "SBP-C", "SCBP-A", "SON-B"])


        let pop102 = dataStore.getStratum(named: "102", within: "Population")
        try #require( pop102 != nil )
        #expect( strata102 == pop102 )

        let strataCBP = strata.first(where: { $0.name == "CBP-C" })
        try #require( strataCBP != nil )
        #expect( dataStore.getIndividuals(for: strataCBP!).count == 150)

        let inds102 = dataStore.getIndividualsWithinStratum(named: "102")
        #expect( inds102.count == 8 )



        // Test for Loci

        let loci = dataStore.getAllLoci()
        #expect( loci.count == 8 )
        #expect( loci.compactMap{ $0.name }.sorted() == ["LTRS","WNT","EN","EF","ZMP","AML","ATPS","MP20"].sorted() )

    }

}
