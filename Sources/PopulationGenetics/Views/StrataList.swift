//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StrataList.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 5/30/25.
//

import SwiftUI

/// A scrollable list of all strata organized by hierarchical level.
///
/// Displays strata grouped by their level (e.g., Region, Population) with
/// expandable sections for each level. Requires a `PopGenStore` in the environment.
struct StrataList: View {
    /// The data store providing stratum data.
    @EnvironmentObject var dataStore: PopGenStore

    private var strata: [StratumReference] {
        return dataStore.getAllStrata()
    }

    private var levels: [String] {
        return Array( Set( self.strata.map { $0.level } ) ).naturalSorted()
    }

    private func strataForLevel(_ level: String) -> [StratumReference] {
        return self.strata.filter { $0.level == level }
    }

    @State var selectedLevel: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading ) {
                ForEach( self.levels, id: \.self ) { level in
                    Section( content: {
                        ForEach( strataForLevel(level)) { stratum in
                            StratumPlacard(name: stratum.name, count: dataStore.individualCount(for: stratum) )
                        }
                    }, header: {
                        Text(level)
                            .font( .largeTitle )
                            .padding(.top )
                    } )
                }
            }
        }
    }
}


#if DEBUG
#Preview {
    StrataList()
        .environmentObject(PopulationGeneticsPreviewData.shared.dataStore)
}
#endif
