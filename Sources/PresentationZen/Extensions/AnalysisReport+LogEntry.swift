//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AnalysisReport+LogEntry.swift
//  PresentationZen
//
//  An analysis report as log entries: the Methods passage, then each note,
//  then the Results passage, all tagged with the analysis's tag and stamped
//  with the time it ran, so a log reads in the order of a manuscript.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix

extension AnalysisReport {

    /// The report as log entries: Methods (`.methods`), the notes, then
    /// Results (`.results`).
    public var logEntries: [LogEntry] {
        let entry = { (type: LogType, message: String) in
            LogEntry(timestamp: date, logType: type, analysisTag: tag, message: message)
        }
        return [entry(.methods, methods)]
            + notes.map { entry($0.logType, $0.message) }
            + [entry(.results, results)]
    }
}
