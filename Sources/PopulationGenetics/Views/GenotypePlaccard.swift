//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck//
//  GenotypePlaccard.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 5/30/25.
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
struct GenotypePlaccard: View {
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
                    .foregroundStyle( Genotype.colorForLineage( lineage: genotype.leftLineage ) )
                Text(":")
                Text("\(genotype.rightAllele)")
                    .foregroundStyle( Genotype.colorForLineage( lineage: genotype.rightLineage ) )
            }

        }

    }
}

#if DEBUG
#Preview("Raw") {
    let geno = Genotype( leftAllele: "A",
                         rightAllele: "B" )
    GenotypePlaccard(genotype: geno )
        .padding(10)
}

#Preview("Identified") {
    let geno = Genotype( leftAllele: "A",
                         rightAllele: "B",
                         leftLingage: Genotype.PaternalLineage,
                         rightLineage: Genotype.MaternalLineage )

    GenotypePlaccard(genotype: geno, showLineage: true )
        .padding(10)
}


#Preview("Unknown") {
    let geno = Genotype( leftAllele: "A",
                         rightAllele: "B",
                         leftLingage: Genotype.AmbiguousLineage,
                         rightLineage: Genotype.AmbiguousLineage )

    GenotypePlaccard(genotype: geno, showLineage: true )
        .padding(10)
}
#endif
