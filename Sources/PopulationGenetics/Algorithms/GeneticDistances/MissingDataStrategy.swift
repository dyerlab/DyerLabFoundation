//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MissingDataStrategy.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//
//  A single locus's pairwise distance is well-defined for missing/haploid
//  calls: `smousePeakallDistance` simply excludes that pair from that locus.
//  The ambiguity appears once you SUM across loci (`geneticDistance(overLoci:)`)
//  — a pair scored at 3 of 8 loci and a pair scored at all 8 both produce a
//  "total squared distance," but the 3-locus pair had fewer chances to
//  accumulate difference, so its total is biased toward looking artificially
//  close. `MissingDataStrategy` is how the caller resolves that ambiguity;
//  there is no single universally-correct answer, so it's exposed rather than
//  picked silently.
//

/// How `geneticDistance(overLoci:strategy:)` handles individual pairs that
/// aren't scored (missing, or a haploid partial call) at every locus in the set.
public enum MissingDataStrategy: Sendable, Equatable {

    /// Divide each pair's summed distance by the number of loci actually
    /// scored for that pair (pairwise deletion). Produces an "average squared
    /// distance per covered locus" — comparable across pairs regardless of
    /// missingness pattern, but on a different absolute scale than a raw sum
    /// over a complete-data panel.
    case perLocusMean

    /// `perLocusMean`, then rescaled by the total number of loci considered —
    /// a "projected total distance" on the same scale a complete-data pair
    /// would show. Identical relative structure to `perLocusMean` (they
    /// differ only by the same constant, `totalLoci`, applied to every pair),
    /// and reduces exactly to the historical unnormalized sum when no pair
    /// has any missing data. This is the default because it's the
    /// least-surprising choice for datasets that are mostly complete.
    case rescaleToTotalLoci

    /// Impute a missing or haploid genotype's allele-count vector as the
    /// locus's expected dosage (`2 × frequency`) under the allele
    /// frequencies observed at that locus, computed from every other
    /// individual with real data there — then compute distance normally, no
    /// pair ever excluded. Unlike `perLocusMean`/`rescaleToTotalLoci`, this
    /// assumes missing genotypes look like a "typical" individual at that
    /// locus (Hardy–Weinberg expectation), which is a real modeling
    /// assumption, not a neutral normalization — prefer this only when that
    /// assumption is reasonable for your data (e.g. missingness unrelated to
    /// genotype, not concentrated in a divergent subpopulation).
    case impute
}
