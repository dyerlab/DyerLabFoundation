//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StrataRarefactionResult.swift
//  PopulationGenetics
//
//  What a `StrataRarefactionAnalysis` produces: gstudio's rarefaction.test()
//  table, with the resampled values kept for plotting distributions, and the
//  manuscript text.
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// Diversity statistics rarefied among strata.
public struct StrataRarefactionResult: Sendable {

    /// The rows, by stratum, then locus (multilocus last), then statistic.
    public let rows: [StrataRarefactionRow]

    /// "Stratum locus" for each cell with fewer genotyped individuals than the subsample size, whose values are
    /// undefined.
    public let shortCells: [String]

    /// The Methods and Results text, with the notes.
    public let report: AnalysisReport

    /// Assembles the result and its report.
    ///
    /// - Parameters:
    ///   - analysis: The analysis that produced the rows.
    ///   - rows: The rows.
    ///   - shortCells: The cells too small to rarefy.
    ///   - options: The options it ran with.
    init(analysis: StrataRarefactionAnalysis, rows: [StrataRarefactionRow], shortCells: [String],
         options: AnalysisOptions) {
        self.rows = rows
        self.shortCells = shortCells
        self.report = analysis.report(rows: rows, shortCells: shortCells, options: options)
    }

    /// The rows for one statistic at one locus (`nil` for the multilocus rows), in stratum order.
    ///
    /// - Parameters:
    ///   - statistic: The statistic.
    ///   - locus: The locus's name, or `nil` for multilocus.
    /// - Returns: One row per stratum.
    public func rows(for statistic: DiversityType, locus: String?) -> [StrataRarefactionRow] {
        rows.filter { $0.statistic == statistic && $0.locus == locus }
    }
}
