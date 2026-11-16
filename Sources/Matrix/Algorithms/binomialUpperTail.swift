//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  binomialUpperTail.swift
//  Matrix
//
//  P(X ≥ k) for X ~ Binomial(n, p), the one-sided p-value of R's
//  binom.test(k, n, p, alternative = "greater"), from the identity
//  P(X ≥ k) = I_p(k, n − k + 1).
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// The probability of at least `successes` successes in `trials` Bernoulli trials, R's
/// `binom.test(successes, trials, p, alternative = "greater")$p.value`.
///
/// - Parameters:
///   - successes: The successes observed, `0...trials`.
///   - trials: The trials (`> 0`).
///   - probability: The success probability in `[0, 1]`.
/// - Returns: `P(X ≥ successes)`, or `NaN` for arguments out of range.
public func binomialUpperTail(successes: Int, trials: Int, probability: Double) -> Double {
    guard trials > 0, (0...trials).contains(successes), (0...1).contains(probability) else { return .nan }
    if successes == 0 { return 1 }
    return regularizedIncompleteBeta(probability, Double(successes), Double(trials - successes + 1))
}
