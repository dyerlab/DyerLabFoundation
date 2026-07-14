//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DiversityType.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 6/5/25.
//

import Foundation

/// Enumerates the types of genetic diversity metrics available for analysis.
///
/// This enum defines standard population genetic statistics organized into
/// allelic and genotypic categories. Each metric has a specific interpretation
/// and use case in population genetics analyses.
public enum DiversityType: String, Sendable, Equatable, Hashable, CaseIterable {
    /// Placeholder for unspecified diversity metric.
    case Undefined = "Undefined"

    // MARK: - Allelic Diversity Metrics

    /// Allelic richness: total number of unique alleles at a locus.
    case A = "A"

    /// Number of common alleles (frequency ≥ 5%) at a locus.
    case A95 = "A95"

    /// Effective number of alleles: diversity accounting for allele frequency distribution (1/Σp²).
    case Ae = "Ae"

    // MARK: - Genotypic Diversity Metrics

    /// Observed heterozygosity: proportion of heterozygous genotypes.
    case Ho = "Ho"

    /// Total heterozygosity: expected heterozygosity across all populations.
    case Ht = "Ht"

    /// Expected heterozygosity (gene diversity): probability that two random alleles differ (1-Σp²).
    case He = "He"

    /// Inbreeding heterozygosity: heterozygosity under inbreeding.
    case Hi = "Hi"

    /// Observed heterozygosity in subpopulations.
    case Hos = "Hos"

    /// Expected heterozygosity in subpopulations.
    case Hes = "Hes"

    /// Proportion of polymorphic loci.
    case Pe = "Pe"

    /// Returns the measurement level for this diversity metric.
    ///
    /// - Allelic metrics: A, A95, Ae
    /// - Genotypic metrics: All others (Ho, He, Ht, etc.)
    var level: DiversityLevel {
        switch self {
        case .A, .A95, .Ae:
            return .Allelic
        default:
            return .Genotypic
        }
    }

}
