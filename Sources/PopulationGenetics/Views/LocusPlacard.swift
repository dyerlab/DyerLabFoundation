//
//  LocusPlacard.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 5/30/25.
//

import SwiftUI

/// A compact view displaying locus information including name, contig, and location.
///
/// Shows the locus name prominently with contig and location details as secondary text.
struct LocusPlacard: View {
    /// The locus to display.
    var locus: Locus
    var body: some View {
        HStack{
            Text(locus.name)
                .font(.title)
            VStack(alignment: .leading){
                Text("Contig: \(locus.contig)")
                Text("Location: \(locus.location)")
            }
            .foregroundStyle(.secondary)
            .font( .footnote )
        }
    }
}

#Preview {
    LocusPlacard(locus: Locus(name: "MPI",
                              location: UInt.random(in: 234234...2342342),
                              contig: "2" ))
    .padding()
}
