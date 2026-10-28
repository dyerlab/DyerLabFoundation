//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StratumPlacard.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2025.05.30.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// A compact view displaying stratum information including name and individual count.
///
/// Shows the stratum name prominently with the number of individuals as secondary text.
/// Takes a plain name/count pair rather than a `StratumReference` directly — the
/// reference itself carries no roster (see `StratumReference`'s doc comment), so the
/// caller (`StrataList`) resolves the count via `PopGenStore.individualCount(for:)`.
struct StratumPlacard: View {
    /// The stratum's name.
    var name: String
    /// The number of individuals tagged with this stratum.
    var count: Int

    var body: some View {
        HStack(alignment: .bottom) {
            Text(name)
                .font(.title)
            VStack(alignment: .leading) {
                Text("N: \(count)")
            }
            .foregroundStyle(.secondary)
            .font(.footnote)
        }
    }
}

// MARK: - Previews

#Preview {
    StratumPlacard(name: "LaV", count: 12)
}
