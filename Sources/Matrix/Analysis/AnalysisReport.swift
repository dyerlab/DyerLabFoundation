//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AnalysisReport.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// What an analysis did and found, written for a manuscript and for the log.
public struct AnalysisReport: Sendable, Equatable {

    /// The technique that was run.
    public let analysisType: AnalysisType

    /// The label the analysis ran under.
    public let tag: AnalysisTag

    /// The options it ran with.
    public let options: AnalysisOptions

    /// A Methods passage, filled from the analysis's data and options.
    public let methods: String

    /// A Results passage, filled from the estimates.
    public let results: String

    /// Decisions made about the data (dropped or imputed values, ...).
    public let notes: [AnalysisNote]

    /// When the analysis was run.
    public let date: Date

    /// Creates a report.
    ///
    /// - Parameters:
    ///   - analysisType: The technique that was run.
    ///   - tag: The label it ran under.
    ///   - options: The options it ran with.
    ///   - methods: The Methods passage.
    ///   - results: The Results passage.
    ///   - notes: Decisions made about the data.
    ///   - date: When it was run (default now).
    public init(analysisType: AnalysisType, tag: AnalysisTag, options: AnalysisOptions,
                methods: String, results: String, notes: [AnalysisNote], date: Date = Date()) {
        self.analysisType = analysisType
        self.tag = tag
        self.options = options
        self.methods = methods
        self.results = results
        self.notes = notes
        self.date = date
    }
}
