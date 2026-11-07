//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DiversityPlotSpec+Legend.swift
//  PopulationGenetics
//
//  Starting text for a saved plot. A legend states how the values were computed,
//  since pooled and within-population heterozygosity differ a great deal under
//  structure, but no counts, which would go stale when the data changes.
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension DiversityPlotSpec {

    /// A short title describing the plot, e.g. `"He by latitude"`.
    public var suggestedTitle: String {
        let symbol = response.rawValue
        if predictor != .none { return "\(symbol) by \(predictor.title.lowercased())" }
        return "Distribution of \(symbol) across \(unit.title.lowercased())"
    }

    /// A figure legend describing how the plot's values were computed.
    ///
    /// - Parameter options: The dataset's choices, which name its kind of group.
    /// - Returns: One or two sentences.
    public func suggestedLegend(options: DiversityPlotOptions) -> String {
        let statistic = "\(response.name.lowercased()) (\(response.rawValue))"
        let unit = effectiveUnit(primaryGroupUnit: options.primaryGroupUnit)
        let basis = basisPhrase(unit: unit, options: options)
        switch predictor {
        case .none:
            let kind = style == .density ? "Kernel density" : "Histogram"
            return "\(kind) of \(statistic) across \(self.unit.title.lowercased()), \(basis)."
        case .locus:
            return "Per-locus \(statistic), \(basis)."
        case .population, .family:
            return "\(statistic.capitalizedFirst) for each \(predictor.title.lowercased()), \(basis)."
        case .latitude, .longitude:
            let group = unit == .family ? "family" : "population"
            return "\(statistic.capitalizedFirst) for each \(group), \(basis), "
                + "plotted against the \(group)'s mean \(predictor.title.lowercased())."
        case .sampleSize:
            let group = unit == .family ? "family" : "population"
            return "\(statistic.capitalizedFirst) for each \(group), \(basis), "
                + "plotted against the number of individuals sampled."
        }
    }

    /// Describes how a value is computed, as a phrase to follow its description.
    ///
    /// - Parameters:
    ///   - unit: The unit each value stands for.
    ///   - options: The dataset's choices, which name its kind of group.
    /// - Returns: A lowercase phrase with no closing period.
    private func basisPhrase(unit: Unit, options: DiversityPlotOptions) -> String {
        switch unit {
        case .locus:
            switch sample {
            case .pooled: return "computed from all adults pooled"
            case .meanWithinGroups: return "averaged across \(options.primaryGroupsTitle)"
            case .group(let name): return "computed within \(name)"
            }
        case .population:
            return locus.map { "at locus \($0)" } ?? "averaged across loci"
        case .family:
            return (locus.map { "at locus \($0)" } ?? "averaged across loci") + " in the offspring"
        case .locusWithinPopulation:
            return "computed separately within each population"
        case .locusWithinFamily:
            return "computed separately within each family's offspring"
        }
    }
}

private extension String {
    /// The string with its first letter capitalised, leaving the rest alone.
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
