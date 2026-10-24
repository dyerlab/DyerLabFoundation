//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  FrequencyPieChart.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2025.06.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI
import Charts

/// A donut chart visualization of allele frequencies at a locus.
///
/// Displays allele frequencies as proportional sectors with labels overlaid
/// on each segment. Uses SwiftUI Charts for rendering.
struct FrequencyPieChart: View {
    /// The frequency data to visualize.
    var frequencies: GenotypeFrequencies

    var body: some View {
        Chart {
            ForEach(frequencies.alleles, id: \.self) { allele in
                SectorMark(angle: .value(
                    Text(verbatim: allele), frequencies.frequency(for: allele)),
                            innerRadius: .ratio(0.25),
                            angularInset: 1.5
                )
                .cornerRadius(5)
                .annotation(position: .overlay) {
                    Text(verbatim: allele)
                        .font(.title2)
                }
                .foregroundStyle(by: .value(
                    Text(verbatim: allele),
                    allele
                ))
            }
        }
        .chartLegend(.hidden)
        .padding()
    }
}

// MARK: - Previews

#Preview {
    FrequencyPieChart(frequencies: GenotypeFrequencies.defaultFrequencies)
}
