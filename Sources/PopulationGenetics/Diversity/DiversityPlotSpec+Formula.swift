//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DiversityPlotSpec+Formula.swift
//  PopulationGenetics
//
//  The builders title results with a formula, `Response ~ Predictor | Conditions` (GeneticStudio's DESIGN.md): `~ 1`
//  is a distribution, and `|` conditions, where a factor alone means each of its levels and `Factor: level` means
//  that one.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

public extension DiversityPlotSpec {

    /// The plot as a formula, such as `He ~ 1`, `Ae ~ Population | Locus: L01` or `He ~ Locus | Pop01`.
    ///
    /// The spec is normalized first, so parameters the plot doesn't use don't appear.
    var formula: String {
        let spec = normalized
        let predictor = switch spec.predictor {
        case .none: "1"
        case .sampleSize: "n"
        default: spec.predictor.title
        }
        var conditions: [String] = []
        if spec.predictor == .none {
            switch spec.unit {
            case .locus: break
            case .population: conditions.append("Population")
            case .family: conditions.append("Family")
            case .locusWithinPopulation: conditions += ["Locus", "Population"]
            case .locusWithinFamily: conditions += ["Locus", "Family"]
            }
        }
        if spec.usesLocus, let locus = spec.locus { conditions.append("Locus: \(locus)") }
        if spec.usesSample, case .group(let name) = spec.sample { conditions.append(name) }
        let formula = "\(spec.response.rawValue) ~ \(predictor)"
        return conditions.isEmpty ? formula : "\(formula) | \(conditions.joined(separator: ", "))"
    }
}
