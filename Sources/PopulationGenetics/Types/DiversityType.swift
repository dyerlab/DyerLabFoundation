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
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2025.06.05.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Enumerates the types of genetic diversity metrics available for analysis.
///
/// This enum defines standard population genetic statistics organized into
/// allelic and genotypic categories. Each metric has a specific interpretation
/// and use case in population genetics analyses.
public enum DiversityType: String, Sendable, Equatable, Hashable, CaseIterable, Codable, Identifiable {
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

    /// Locus polymorphic index, `Σp(1-p)`.
    case Pe = "Pe"

    /// The metric itself.
    public var id: Self { self }

    /// The metric's name, for legends.
    public var name: String {
        switch self {
        case .Undefined: "Undefined"
        case .A: "Allelic richness"
        case .A95: "Number of common alleles"
        case .Ae: "Effective number of alleles"
        case .Ho: "Observed heterozygosity"
        case .Ht: "Total heterozygosity"
        case .He: "Expected heterozygosity"
        case .Hi: "Inbreeding heterozygosity"
        case .Hos: "Observed subpopulation heterozygosity"
        case .Hes: "Expected subpopulation heterozygosity"
        case .Pe: "Locus polymorphic index"
        }
    }

    /// The metric's name with its symbol, for axes, menus and legends.
    public var label: String { "\(name) (\(rawValue))" }

    /// Returns the measurement level for this diversity metric.
    ///
    /// - Allelic metrics: A, A95, Ae
    /// - Genotypic metrics: All others (Ho, He, Ht, etc.)
    public var level: DiversityLevel {
        switch self {
        case .A, .A95, .Ae:
            return .Allelic
        default:
            return .Genotypic
        }
    }

}
