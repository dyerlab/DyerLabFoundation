//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DiversityLevel.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 6/5/25.
//

import Foundation

/// Categorizes genetic diversity metrics by the unit of measurement.
///
/// Diversity can be measured at different organizational levels:
/// - **Allelic**: Diversity measured at the allele level (e.g., A, Ae, A95)
/// - **Genotypic**: Diversity measured at the genotype level (e.g., Ho, He, Ht)
public enum DiversityLevel: String, Sendable, Equatable, Hashable, CaseIterable {
    /// Allele-based diversity metrics (A, Ae, A95).
    case Allelic = "Allelic"

    /// Genotype-based diversity metrics (Ho, He, Ht, etc.).
    case Genotypic = "Genotypic"
}
