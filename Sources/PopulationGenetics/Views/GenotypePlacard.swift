//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypePlacard.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2025.05.30.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// A view displaying a genotype with optional lineage color-coding.
///
/// When `showLineage` is `false`, displays the genotype as "left:right".
/// When `true`, colors each allele based on its parental origin:
/// - Pink for maternal
/// - Blue for paternal
/// - Orange for ambiguous
/// - Red for impossible assignments
struct GenotypePlacard: View {
    /// The genotype to display.
    let genotype: Genotype
    /// Whether to show lineage color-coding on the alleles.
    @State var showLineage: Bool = false

    var body: some View {
        if !showLineage {
            Text("\(genotype.leftAllele):\(genotype.rightAllele)")
        } else {
            HStack(spacing: 0) {
                Text("\(genotype.leftAllele)")
                    .foregroundStyle(Genotype.colorForLineage(lineage: genotype.leftLineage))
                Text(":")
                Text("\(genotype.rightAllele)")
                    .foregroundStyle(Genotype.colorForLineage(lineage: genotype.rightLineage))
            }

        }

    }
}

#if DEBUG

// MARK: - Previews

#Preview("Raw") {
    let geno = Genotype(leftAllele: "A",
                         rightAllele: "B")
    GenotypePlacard(genotype: geno)
        .padding(10)
}

#Preview("Identified") {
    let geno = Genotype(leftAllele: "A",
                         rightAllele: "B",
                         leftLineage: Genotype.PaternalLineage,
                         rightLineage: Genotype.MaternalLineage)

    GenotypePlacard(genotype: geno, showLineage: true)
        .padding(10)
}

#Preview("Unknown") {
    let geno = Genotype(leftAllele: "A",
                         rightAllele: "B",
                         leftLineage: Genotype.AmbiguousLineage,
                         rightLineage: Genotype.AmbiguousLineage)

    GenotypePlacard(genotype: geno, showLineage: true)
        .padding(10)
}
#endif
