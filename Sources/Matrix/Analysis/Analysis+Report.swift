//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Analysis+Report.swift
//  Matrix
//
//  Running an analysis with its report. The values available to a template
//  are, in increasing precedence: the common keys below, the analysis's
//  `methodsValues(options:)` and the outcome's `resultsValues`. Common keys:
//  `analysis`, `tag`, `iterations`, `seed`, `statistic`, `pValue`
//  ("P = 0.012" or "not tested") and `interval`.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension Analysis {

    /// Runs the analysis and writes its report.
    ///
    /// - Parameters:
    ///   - options: Iteration count and seed.
    ///   - template: The wording to fill (default `Self.reportTemplate`).
    /// - Returns: The outcome and report, or `nil` if the analysis can't run.
    public func perform(options: AnalysisOptions = AnalysisOptions(),
                        template: AnalysisReportTemplate? = nil) -> AnalysisRun<Outcome>? {
        guard let outcome = run(options: options) else { return nil }
        return AnalysisRun(outcome: outcome, report: report(for: outcome, options: options, template: template))
    }

    /// Writes the report for an outcome this analysis produced.
    ///
    /// - Parameters:
    ///   - outcome: The outcome of `run(options:)`.
    ///   - options: The options it ran with.
    ///   - template: The wording to fill (default `Self.reportTemplate`).
    /// - Returns: The report.
    public func report(for outcome: Outcome, options: AnalysisOptions,
                       template: AnalysisReportTemplate? = nil) -> AnalysisReport {
        let template = template ?? Self.reportTemplate
        let values = reportValues(for: outcome, options: options)
        return AnalysisReport(analysisType: Self.analysisType, tag: tag, options: options,
                              methods: AnalysisReportTemplate.fill(template.methods, with: values),
                              results: AnalysisReportTemplate.fill(template.results, with: values),
                              notes: notes + outcome.notes)
    }

    /// Every placeholder value for an outcome: the common keys, then the
    /// Methods values, then the Results values.
    ///
    /// - Parameters:
    ///   - outcome: The outcome of `run(options:)`.
    ///   - options: The options it ran with.
    /// - Returns: The value for each key.
    public func reportValues(for outcome: Outcome, options: AnalysisOptions) -> [String: String] {
        var values: [String: String] = [
            "analysis": Self.analysisType.displayName,
            "tag": tag.rawValue,
            "iterations": AnalysisReport.count(options.iterations),
            "seed": String(options.seed),
            "statistic": AnalysisReport.number(outcome.statistic),
            "pValue": AnalysisReport.pValue(outcome.pValue),
            "interval": AnalysisReport.interval(outcome.interval),
        ]
        values.merge(methodsValues(options: options)) { $1 }
        values.merge(outcome.resultsValues) { $1 }
        return values
    }
}
