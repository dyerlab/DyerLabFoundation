//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  hypergeometricProbability.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 7/4/26.
//

import Foundation

/// Probability of drawing an exact number of successes when sampling without
/// replacement from a finite population.
///
/// This is the hypergeometric distribution: `populationSize` items contain
/// `successesInPopulation` marked as successes, `draws` items are removed without
/// replacement, and this returns the chance that exactly `observedSuccesses` of them
/// are successes.
///
/// P(X = k) = C(K, k) · C(N - K, n - k) / C(N, n)
///
/// - Parameters:
///   - populationSize: Total number of items in the population (N).
///   - successesInPopulation: Number of success items in the population (K).
///   - draws: Number of items drawn without replacement (n).
///   - observedSuccesses: Number of successes to compute the probability for (k).
/// - Returns: `P(X = observedSuccesses)`, `0.0` if `observedSuccesses` is outside the
///   range that population can produce, or `Double.nan` if the parameters describe an
///   impossible population (negative counts, or `successesInPopulation` / `draws`
///   exceeding `populationSize`).
///
/// ## Example
/// ```swift
/// // A 40-card deck holds 4 copies of a card. What's the probability of
/// // drawing exactly 1 copy in an opening hand of 7 cards?
/// let probability = hypergeometricProbability(
///     populationSize: 40,
///     successesInPopulation: 4,
///     draws: 7,
///     observedSuccesses: 1
/// )
/// ```
public func hypergeometricProbability(populationSize: Int, successesInPopulation: Int, draws: Int, observedSuccesses: Int) -> Double {

    guard populationSize >= 0,
          successesInPopulation >= 0, successesInPopulation <= populationSize,
          draws >= 0, draws <= populationSize,
          observedSuccesses >= 0
    else {
        return Double.nan
    }

    let failuresInPopulation = populationSize - successesInPopulation

    // The draw can only contain observedSuccesses when there are enough successes
    // to supply them and enough failures to fill out the remaining draws.
    let lowerBound = max(0, draws - failuresInPopulation)
    let upperBound = min(draws, successesInPopulation)

    guard observedSuccesses >= lowerBound, observedSuccesses <= upperBound else {
        return 0.0
    }

    let logNumerator = logBinomialCoefficient(successesInPopulation, observedSuccesses)
        + logBinomialCoefficient(failuresInPopulation, draws - observedSuccesses)
    let logDenominator = logBinomialCoefficient(populationSize, draws)

    return exp(logNumerator - logDenominator)
}

/// Natural log of the binomial coefficient C(n, k), via the log-gamma function so
/// large populations don't overflow intermediate factorials.
private func logBinomialCoefficient(_ n: Int, _ k: Int) -> Double {
    lgamma(Double(n + 1)) - lgamma(Double(k + 1)) - lgamma(Double(n - k + 1))
}
