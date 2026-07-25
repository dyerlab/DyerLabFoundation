//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  LogType.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  An open, extensible label for what kind of event a persisted log entry
//  records (file I/O, a warning, an error, a documented assumption, ...).
//  Deliberately a struct wrapping a raw string, not an enum, for the same
//  reason as `AnalysisTag`: Swift enums are closed across modules, so a
//  fixed set of cases here would force every consuming package to route new
//  log categories through Matrix. This ships the tagging *mechanism* plus a
//  handful of common built-ins — any module can mint its own via a
//  `static let`/`static func` extension, the same way `AnalysisTag` is
//  extended (see `AMOVA.swift`'s `AnalysisTag.amovaPhiST`).
//

/// An open, string-backed label identifying the category of a persisted log
/// entry. Built-in cases cover common needs; any module can mint its own
/// values via a `static let`/`static func` extension.
public struct LogType: Sendable, Equatable, Hashable, CustomStringConvertible {

    /// The tag's underlying label.
    public let rawValue: String

    /// Creates a log type with the given label.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }

    /// File import/export, save/load, or other on-disk I/O.
    public static let fileIO = LogType("fileIO")

    /// A non-fatal condition worth flagging, but not an error.
    public static let warning = LogType("warning")

    /// A failure that prevented an operation from completing.
    public static let error = LogType("error")

    /// A documented assumption made in the absence of certainty (e.g. a
    /// default chosen when input data was ambiguous or incomplete).
    public static let assumption = LogType("assumption")

    /// A neutral, informational note not covered by the above.
    public static let info = LogType("info")
}
