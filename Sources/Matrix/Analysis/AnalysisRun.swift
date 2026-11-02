//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AnalysisRun.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// The outcome of running an analysis, with its report.
public struct AnalysisRun<Outcome: AnalysisOutcome>: Sendable {

    /// The estimates.
    public let outcome: Outcome

    /// The Methods and Results text and the decisions made, for the log.
    public let report: AnalysisReport

    /// Creates a run.
    ///
    /// - Parameters:
    ///   - outcome: The estimates.
    ///   - report: The report.
    public init(outcome: Outcome, report: AnalysisReport) {
        self.outcome = outcome
        self.report = report
    }
}
