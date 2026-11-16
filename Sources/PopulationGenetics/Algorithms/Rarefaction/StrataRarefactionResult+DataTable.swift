//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StrataRarefactionResult+DataTable.swift
//  PopulationGenetics
//
//  The rarefied values as tables for plotting and export: every subsample's
//  value in long form (one row per stratum and draw, for a distribution per
//  stratum), and the summary (observed, estimate and interval per stratum).
//  The tables export to R and CSV through DataTable.
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import PresentationZen

extension StrataRarefactionResult {

    /// Every subsample's value of one statistic, one row per stratum and draw: `stratum`, `draw` and the
    /// statistic's raw value (e.g. `Ae`), with roles x = stratum, y = value and series = stratum. Undefined draws
    /// are left out.
    ///
    /// - Parameters:
    ///   - statistic: The statistic.
    ///   - locus: The locus's name, or `nil` (the default) for the multilocus values.
    /// - Returns: The table, or `nil` if no stratum has a defined value.
    public func distributionTable(for statistic: DiversityType, locus: String? = nil) -> DataTable? {
        var strata: [String] = [], draws: [Double] = [], values: [Double] = []
        for row in rows(for: statistic, locus: locus) {
            for (draw, value) in row.values.enumerated() where value.isFinite {
                strata.append(row.stratum)
                draws.append(Double(draw + 1))
                values.append(value)
            }
        }
        guard !values.isEmpty else { return nil }
        let name = statistic.rawValue
        return DataTable(numbers: [name: values, "draw": draws], strings: ["stratum": strata],
                         roles: [.x: "stratum", .y: name, .series: "stratum"])
    }

    /// One row per stratum for a statistic: `stratum`, `observed`, `estimate`, `low` and `high`, with roles
    /// x = stratum and y = estimate. Undefined values are `NaN`.
    ///
    /// - Parameters:
    ///   - statistic: The statistic.
    ///   - locus: The locus's name, or `nil` (the default) for the multilocus values.
    /// - Returns: The table, or `nil` if there are no rows.
    public func summaryTable(for statistic: DiversityType, locus: String? = nil) -> DataTable? {
        let selected = rows(for: statistic, locus: locus)
        guard !selected.isEmpty else { return nil }
        return DataTable(numbers: ["observed": selected.map { $0.observed ?? .nan },
                                   "estimate": selected.map { $0.estimate ?? .nan },
                                   "low": selected.map { $0.interval?.lowerBound ?? .nan },
                                   "high": selected.map { $0.interval?.upperBound ?? .nan }],
                         strings: ["stratum": selected.map(\.stratum)],
                         roles: [.x: "stratum", .y: "estimate"])
    }
}
