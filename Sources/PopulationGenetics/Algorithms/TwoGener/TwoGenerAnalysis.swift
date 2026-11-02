//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  TwoGenerAnalysis.swift
//  PopulationGenetics
//
//  Smouse, Dyer, Westfall & Sork (2001) Two-generation analysis of pollen
//  flow across a landscape. I. Male gamete heterogeneity among females.
//  Evolution 55:260–271. The gamete scoring is in `TwoGenerGametes`; the
//  AMOVA is Matrix's `VarianceDecompositionAnalysis`, whose permutations
//  shuffle gametes among mothers, as the paper prescribes.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// Two-generation analysis of pollen pool structure (`AnalysisType.twoGener`).
///
/// Each offspring's paternal gamete is recovered by removing its mother's
/// contribution and scored as an allele vector. When mother and offspring
/// share a heterozygote, the paternal allele is weighted by the study-wide
/// pollen-pool frequencies; a missing genotype is imputed from those
/// frequencies; an offspring incompatible with its mother is dropped. AMOVA
/// of the gametes with mothers as strata gives Φ_FT, the heterogeneity of the
/// pollen pools the mothers sampled. Every decision is recorded in ``notes``,
/// which `perform(options:)` carries into the report with the Methods and
/// Results text.
///
/// ## Usage
///
/// ```swift
/// if let twoGener = TwoGenerAnalysis(matrix: genotypes, design: families),
///    let run = twoGener.perform(options: AnalysisOptions(iterations: 999, seed: 1)) {
///     print(run.outcome.phiFT, run.outcome.pValue ?? .nan)
///     try await store.appendLog(report: run.report)
/// }
/// ```
public struct TwoGenerAnalysis: Analysis {

    /// `AnalysisType.twoGener`.
    public static let analysisType: AnalysisType = .twoGener

    /// The label for the outcome.
    public let tag: AnalysisTag

    /// How the pollen-pool frequencies were estimated.
    public let frequencyMethod: PollenPoolFrequencyMethod

    /// The study-wide pollen-pool allele frequencies, per locus and indexed by
    /// allele index; empty for a locus with no recovered paternal alleles.
    public var pollenPool: [[Double]] { gametes.pollenPool }

    /// The offspring ordinals analysed, in gamete order.
    public var offspring: [Int] { gametes.offspring }

    /// The family index (into the design's families) of each analysed gamete.
    public var partition: [Int] { gametes.partition }

    /// `N × N` squared distances among the analysed paternal gametes
    /// (Smouse et al. 2001, eqs. 1–2).
    public var squaredDistances: [[Double]] { gametes.squaredDistances }

    /// The decisions made while recovering and scoring the gametes.
    public var notes: [AnalysisNote] { gametes.notes }

    /// The scored gametes and the counts the report draws on.
    let gametes: TwoGenerGametes

    /// The AMOVA of the gametes.
    let amova: VarianceDecompositionAnalysis

    /// Recovers and scores the paternal gametes and prepares the AMOVA.
    ///
    /// - Parameters:
    ///   - matrix: Genotypes of mothers and offspring.
    ///   - design: The maternal families.
    ///   - frequencyMethod: How pollen-pool frequencies are estimated (default
    ///     `.expectationMaximization`; `.paternalAverage` reproduces the
    ///     original 2Gener and GenAlEx estimate).
    ///   - tag: The label for the outcome (default `.twoGenerPhiFT`).
    /// - Returns: `nil` if fewer than two mothers keep an offspring, or no
    ///   mother has more than one, so there is no among- or within-mother
    ///   variation to estimate.
    public init?(matrix: GenotypeMatrix,
                 design: ParentageDesign,
                 frequencyMethod: PollenPoolFrequencyMethod = .expectationMaximization,
                 tag: AnalysisTag = .twoGenerPhiFT) {
        let gametes = TwoGenerGametes(matrix: matrix, design: design, method: frequencyMethod)
        guard var amova = VarianceDecompositionAnalysis(squaredDistances: gametes.squaredDistances,
                                                        partition: gametes.partition,
                                                        tag: tag) else { return nil }
        amova.statisticLabel = "Φ_FT"
        amova.unitLabel = "paternal gametes"
        amova.groupLabel = "mothers"
        self.amova = amova
        self.tag = tag
        self.frequencyMethod = frequencyMethod
        self.gametes = gametes
    }

    /// Runs the AMOVA, testing Φ_FT by shuffling gametes among mothers.
    ///
    /// - Parameter options: Permutation count and seed.
    /// - Returns: The outcome; never `nil`.
    public func run(options: AnalysisOptions) -> TwoGenerOutcome? {
        amova.run(options: options).map {
            TwoGenerOutcome(amova: $0, pollenPool: pollenPool, gameteCount: offspring.count,
                            motherCount: Set(partition).count)
        }
    }
}
