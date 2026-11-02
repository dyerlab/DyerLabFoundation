//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AnalysisNote.swift
//  Matrix
//
//  A decision an analysis made about its data (an offspring dropped, a
//  missing genotype imputed). Matrix can't see PresentationZen's `LogEntry`,
//  so notes are this plain pair, and PresentationZen turns an
//  `AnalysisReport` (and its notes) into log entries.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// A decision an analysis made about its data, for the log.
public struct AnalysisNote: Sendable, Equatable, Hashable {

    /// The kind of note: usually `.assumption` or `.warning`.
    public let logType: LogType

    /// What was decided, in a sentence.
    public let message: String

    /// Creates a note.
    ///
    /// - Parameters:
    ///   - logType: The kind of note.
    ///   - message: What was decided, in a sentence.
    public init(_ logType: LogType, _ message: String) {
        self.logType = logType
        self.message = message
    }
}
