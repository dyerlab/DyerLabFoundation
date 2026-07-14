//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeFrequenciesTable.swift
//  GeneticStudio
//
//  Created by Rodney Dyer on 5/4/24.
//

import SwiftUI

/// A horizontally scrollable table displaying allele names and their frequencies.
///
/// Each column shows an allele name (bold) above its frequency value,
/// formatted to four decimal places.
struct GenotypeFrequencyTable: View {
    /// The frequency data to display.
    var freq: GenotypeFrequencies

    var columns: [GridItem] {
        return Array(repeating: GridItem.init(), count: freq.alleles.count)
    }

    var body: some View {
        ScrollView(.horizontal)  {
            LazyVGrid(columns: self.columns, content: {
                ForEach( freq.alleles, id: \.self) { allele in
                    VStack {
                        Text(allele)
                            .bold()
                        Text(freq.frequency(for: allele), format: .number.rounded(increment: 0.0001))
                            .fixedSize()
                    }
                }
            })
        }
    }
}

#Preview {
    GenotypeFrequencyTable( freq: GenotypeFrequencies.defaultFrequencies )
}
