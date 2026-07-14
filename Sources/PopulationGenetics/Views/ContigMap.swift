//
//  ContigMap.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 6/25/25.
//

import SwiftUI

/// A visualization of loci positions along a genomic contig.
///
/// Displays loci as markers along a linear representation of a chromosome or contig.
/// Currently a placeholder for future implementation.
struct ContigMap: View {
    /// The loci to display on the contig map.
    var loci: [Locus]

    private var scaleMin: Double {
        if let locus = loci.first {
            return Double( locus.location )
        } else {
            return 0.0
        }
    }

    private var scaleMax: Double {
        if let locus = loci.last {
            return Double( locus.location )
        } else {
            return 1.0
        }
    }

    var body: some View {
        VStack {
            Spacer()


        }
    }
}

#if DEBUG
#Preview {
    ContigMap( loci: PopulationGeneticsPreviewData.exampleLoci )
}
#endif
