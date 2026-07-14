//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  LocusList.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 5/30/25.
//

import SwiftUI

/// A navigable list of all loci in the data store.
///
/// Displays loci sorted by contig and location. Each locus shows its name,
/// contig, and physical location. Requires a `PopGenStore` in the environment.
struct LocusList: View {
    /// The data store providing locus data.
    @EnvironmentObject var dataStore: PopGenStore

    private var loci: [Locus] {
        return dataStore.getAllLoci()
    }

    var body: some View {
        List(loci.sorted() ) { locus in
            LocusPlacard(locus: locus )
        }
        .navigationTitle("Loci")
    }
}

#if DEBUG
#Preview {
    LocusList()
        .environmentObject(PopulationGeneticsPreviewData.shared.dataStore)
}
#endif
