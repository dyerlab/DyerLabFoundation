//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DiversityRarefactionAnalysis.swift
//  PopulationGenetics
//
//  Matrix's rarefaction technique applied to genetic diversity. It fronts
//  `Rarefaction` / `GenotypicRarefaction` rather than Matrix's generic
//  `RarefactionAnalysis` because the pooled-allele method resamples alleles,
//  not the individuals the subsample size counts, and those functions already
//  handle that and missing alleles.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// Rarefaction of one locus's genetic diversity (`AnalysisType.rarefaction`).
public struct DiversityRarefactionAnalysis: Analysis {

    /// `AnalysisType.rarefaction`.
    public static let analysisType: AnalysisType = .rarefaction

    /// The genotypes at one locus.
    public let genotypes: [Genotype]

    /// The diversity measure to rarefy.
    public let diversityType: DiversityType

    /// The subsample size, in individuals.
    public let size: Int

    /// Whether `.A`, `.A95` and `.Ae` resample whole individuals (keeping each
    /// one's allele pair) rather than pooled alleles. `.Ho` and `.He` always
    /// resample individuals.
    public let individualBased: Bool

    /// `.rarefaction(diversityType)`.
    public var tag: AnalysisTag { .rarefaction(diversityType) }

    /// Creates the analysis.
    ///
    /// - Parameters:
    ///   - genotypes: The genotypes at one locus.
    ///   - type: The diversity measure (`.A`, `.A95`, `.Ae`, `.Ho` or `.He`).
    ///   - size: The subsample size, smaller than `genotypes.count`.
    ///   - individualBased: Resample individuals rather than pooled alleles for
    ///     the allelic measures (default `false`).
    /// - Returns: `nil` if `type` is not one of the five supported measures or
    ///   `size` is not in `1..<genotypes.count`.
    public init?(genotypes: [Genotype], type: DiversityType, size: Int, individualBased: Bool = false) {
        guard [.A, .A95, .Ae, .Ho, .He].contains(type),
              size > 0, size < genotypes.count else { return nil }
        self.genotypes = genotypes
        self.diversityType = type
        self.size = size
        self.individualBased = individualBased
    }

    /// Runs the rarefaction.
    ///
    /// - Parameter options: Number of subsamples and seed.
    /// - Returns: The rarefied estimates, or `nil` if the pooled-allele method
    ///   is used with fewer than two iterations or a `size` below `10`.
    public func run(options: AnalysisOptions) -> RarefactionOutcome? {
        let result = individualBased
            ? GenotypicRarefaction(genotypes: genotypes, type: diversityType, size: size,
                                   iterations: options.iterations, seed: options.seed)
            : Rarefaction(genotypes: genotypes, type: diversityType, size: size,
                          iterations: options.iterations, seed: options.seed)
        return result.map { RarefactionOutcome(tag: tag, resampled: $0) }
    }
}
