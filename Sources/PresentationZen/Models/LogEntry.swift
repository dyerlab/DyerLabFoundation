//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  LogEntry.swift
//  DyerLabFoundation
//
//  A timestamped, freeform note persisted alongside a project's data —
//  "we imported this file and dropped 3 individuals with no genotypes",
//  "assumed missing coordinates meant the population centroid", "AMOVA
//  failed because the partition was empty", etc. Sits next to
//  `AnalysisResult`: that type is a full Markdown writeup for a single
//  analysis; this one is a lightweight, append-only running log spanning
//  the whole project's lifetime, not tied to any one result.
//

import Foundation
import Matrix

/// A single timestamped log entry persisted alongside a project's data.
public struct LogEntry: Sendable, Identifiable, Equatable {

    /// Unique identifier for this entry.
    public var id: UUID

    /// When this entry was recorded.
    public var timestamp: Date

    /// What kind of event this is (file I/O, warning, error, assumption, ...).
    public var logType: LogType

    /// Which analysis this entry pertains to, if any. `nil` for entries not
    /// tied to a specific analysis (e.g. most `fileIO` entries).
    public var analysisTag: AnalysisTag?

    /// Freeform description of what happened.
    public var message: String

    /// Initializes a new log entry.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new `UUID`).
    ///   - timestamp: When this entry was recorded (defaults to now).
    ///   - logType: What kind of event this is.
    ///   - analysisTag: Which analysis this pertains to, if any.
    ///   - message: Freeform description of what happened.
    public init(id: UUID = UUID(), timestamp: Date = Date(), logType: LogType,
                analysisTag: AnalysisTag? = nil, message: String) {
        self.id = id
        self.timestamp = timestamp
        self.logType = logType
        self.analysisTag = analysisTag
        self.message = message
    }
}
