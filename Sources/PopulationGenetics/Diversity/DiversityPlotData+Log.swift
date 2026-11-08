//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DiversityPlotData+Log.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix
import PresentationZen

public extension AnalysisTag {
    /// The label of a diversity plot's log entries.
    static let diversityPlot = AnalysisTag("diversityPlot")
}

public extension DiversityPlotData {

    /// The project log's record of a saved diversity plot: what it shows, then any values it leaves out.
    ///
    /// - Parameters:
    ///   - title: The plot's title.
    ///   - legend: The plot's legend, which says what was computed.
    ///   - date: When it was saved (default now).
    /// - Returns: A `.methods` entry, then an `.assumption` entry for each note.
    func logEntries(title: String, legend: String, date: Date = Date()) -> [LogEntry] {
        let heading = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = legend.trimmingCharacters(in: .whitespacesAndNewlines)
        let methods = text.isEmpty ? "Plotted \(heading)." : "Plotted \(heading): \(text)"
        return [LogEntry(timestamp: date, logType: .methods, analysisTag: .diversityPlot, message: methods)]
            + exportNotes.map { LogEntry(timestamp: date, logType: .assumption, analysisTag: .diversityPlot,
                                         message: $0) }
    }
}
