//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IndividualList.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 5/30/25.
//

import SwiftUI

/// A navigable list of all individuals in the data store.
///
/// Displays individuals sorted alphabetically with their spatial coordinates
/// when available. Requires a `PopGenStore` in the environment.
struct IndividualList: View {
    /// The data store providing individual data.
    @EnvironmentObject var dataStore: PopGenStore

    private var individuals: [Individual] {
        return dataStore.fetchIndividuals()
    }

    var body: some View {
        List(individuals) { individual in
            IndividualPlacard(individual: individual)
        }
        .navigationTitle("Individuals")
    }
}

#if DEBUG
#Preview {
    IndividualList()
        .environmentObject(PopulationGeneticsPreviewData.shared.dataStore)
}
#endif
