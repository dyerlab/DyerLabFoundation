//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  hypergeometricScenarios.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 7/4/26.
//

import Foundation
import Matrix

/// Summarizes a hypergeometric draw into "at least", "exact", and "fewer than"
/// probabilities, ready to hand to a chart.
///
/// Built on ``hypergeometricProbability(populationSize:successesInPopulation:draws:observedSuccesses:)``,
/// this answers the practical framing of a draw-without-replacement question —
/// e.g. "by turn 4, what's the chance I've drawn at least one copy of this
/// card, exactly one, or none at all?" — as a three-row `DataTable` with an
/// `x`/`y` role mapping already set for plotting.
///
/// - Parameters:
///   - populationSize: Total number of items in the population (N).
///   - successesInPopulation: Number of success items in the population (K).
///   - draws: Number of items drawn without replacement (n).
///   - observedSuccesses: The success count the scenarios are measured against (k).
/// - Returns: A `DataTable` with a `scenario` column (`atLeast`, `exact`, `lessThan`)
///   and a `probability` column. Every probability is `Double.nan` if the parameters
///   describe an impossible population.
///
/// ## Example
/// ```swift
/// // A 40-card deck holds 4 copies of a card; 10 cards seen by turn 4.
/// let scenarios = hypergeometricScenarios(
///     populationSize: 40,
///     successesInPopulation: 4,
///     draws: 10,
///     observedSuccesses: 1
/// )
/// ```
public func hypergeometricScenarios(populationSize: Int, successesInPopulation: Int, draws: Int, observedSuccesses: Int) -> DataTable {

    let scenarioNames = ["atLeast", "exact", "lessThan"]

    guard populationSize >= 0,
          successesInPopulation >= 0, successesInPopulation <= populationSize,
          draws >= 0, draws <= populationSize,
          observedSuccesses >= 0
    else {
        return DataTable(
            numbers: ["probability": [Double.nan, Double.nan, Double.nan]],
            strings: ["scenario": scenarioNames],
            roles: [.x: "scenario", .y: "probability"]
        )
    }

    let exactProbability = hypergeometricProbability(
        populationSize: populationSize,
        successesInPopulation: successesInPopulation,
        draws: draws,
        observedSuccesses: observedSuccesses
    )

    let maximumSuccesses = min(draws, successesInPopulation)
    let atLeastProbability: Double
    if observedSuccesses > maximumSuccesses {
        atLeastProbability = 0.0
    } else {
        atLeastProbability = (observedSuccesses...maximumSuccesses).reduce(0.0) { total, successes in
            total + hypergeometricProbability(
                populationSize: populationSize,
                successesInPopulation: successesInPopulation,
                draws: draws,
                observedSuccesses: successes
            )
        }
    }
    let lessThanProbability = 1.0 - atLeastProbability

    return DataTable(
        numbers: ["probability": [atLeastProbability, exactProbability, lessThanProbability]],
        strings: ["scenario": scenarioNames],
        roles: [.x: "scenario", .y: "probability"]
    )
}
