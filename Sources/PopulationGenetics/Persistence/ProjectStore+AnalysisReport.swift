//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ProjectStore+AnalysisReport.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import PresentationZen

extension ProjectStore {

    /// Appends an analysis report to the log (Methods, the notes, then
    /// Results), in one transaction.
    ///
    /// - Parameter report: The report from `Analysis.perform(options:)`.
    /// - Throws: As ``appendLog(_:)-(LogEntry)``.
    public func appendLog(report: AnalysisReport) async throws {
        try await appendLog(report.logEntries)
    }
}
