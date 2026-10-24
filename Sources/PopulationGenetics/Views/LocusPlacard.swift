//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  LocusPlacard.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2025.05.30.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// A compact view displaying locus information including name, contig, and location.
///
/// Shows the locus name prominently with contig and location details as secondary text.
struct LocusPlacard: View {
    /// The locus to display.
    var locus: Locus
    var body: some View {
        HStack {
            Text(locus.name)
                .font(.title)
            VStack(alignment: .leading) {
                Text("Contig: \(locus.contig)")
                Text("Location: \(locus.location)")
            }
            .foregroundStyle(.secondary)
            .font(.footnote)
        }
    }
}

// MARK: - Previews

#Preview {
    LocusPlacard(locus: Locus(name: "MPI",
                              location: UInt.random(in: 234234...2342342),
                              contig: "2"))
    .padding()
}
