//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IBDResult.swift
//  PopulationGenetics
//
//  What an isolation-by-distance test found: the spec with its results, the
//  Mantel outcome (pairs, regression and null distribution) and the report
//  the log keeps. A saved analysis keeps the pairs and the spec; the null
//  distribution itself isn't saved, only its P.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix
import PresentationZen

/// The outcome of an ``IBDAnalysis``.
public struct IBDResult: Sendable {

    /// What was tested, with ``IBDSpec/result`` filled in.
    public let spec: IBDSpec
    /// The Mantel test: the pairs, the correlation, the regression line and any null distribution.
    public let outcome: MantelOutcome
    /// The Methods, Results and notes for the log.
    public let report: AnalysisReport
    /// Whether the adults are the mothers of parent/offspring data.
    public let isParentOffspring: Bool
    /// The genetic units left out because they have no coordinates.
    public let unlocated: [String]

    /// Creates a result.
    ///
    /// - Parameters:
    ///   - spec: What was tested, with its results.
    ///   - outcome: The Mantel outcome.
    ///   - report: The report for the log.
    ///   - isParentOffspring: Whether the adults are the mothers of parent/offspring data.
    ///   - unlocated: The units left out for want of coordinates.
    public init(spec: IBDSpec, outcome: MantelOutcome, report: AnalysisReport, isParentOffspring: Bool,
                unlocated: [String] = []) {
        self.spec = spec
        self.outcome = outcome
        self.report = report
        self.isParentOffspring = isParentOffspring
        self.unlocated = unlocated
    }

    // MARK: - Contents

    /// The analysis's title, such as "Isolation by distance among Population".
    public var title: String {
        spec.title(isParentOffspring: isParentOffspring)
    }

    /// The scatter of pairs, with the regression line.
    public var scatter: PairwiseScatter {
        outcome.scatter(xLabel: spec.separationLabel, yLabel: spec.geneticLabel)
    }

    /// The Mantel and regression statistics as a table.
    public var dataTable: DataTable {
        spec.resultsTable ?? DataTable(frame: .init())
    }

    /// The suggested legend: the report's Methods and Results.
    public var legend: String {
        report.methods + " " + report.results
    }
}
