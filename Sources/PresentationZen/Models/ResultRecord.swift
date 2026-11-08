//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ResultRecord.swift
//  PresentationZen
//
//  A figure that records an analysis is a frozen result: it keeps the log text written when it was run, so its page
//  reads the same however the project's log or data change later. The data version is an opaque id the app changes
//  with each edit to the data (and restores on undo), so an edit that was undone doesn't make a result look stale.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// What a figure records about the analysis that made it: its log text, the analyst's notes, and the data it used.
public struct ResultRecord: Equatable, Hashable, Sendable {
    /// The Methods text, as written when the analysis ran.
    public var methods: String
    /// The Results text, as written when the analysis ran.
    public var results: String
    /// The analysis's notes (units left out, warnings), in order.
    public var notes: [String]
    /// The analyst's own notes on the result; `""` if none.
    public var analystNotes: String
    /// The id of the data version the analysis ran against, or `nil` if unknown.
    public var dataVersion: String?
    /// When that data version was made, or `nil` if unknown.
    public var dataModifiedAt: Date?
    /// The version of the program that ran the analysis, or `nil` if unknown.
    public var appVersion: String?

    /// Creates a record.
    ///
    /// - Parameters:
    ///   - methods: The Methods text.
    ///   - results: The Results text.
    ///   - notes: The analysis's notes.
    ///   - analystNotes: The analyst's own notes.
    ///   - dataVersion: The id of the data version the analysis ran against.
    ///   - dataModifiedAt: When that data version was made.
    ///   - appVersion: The version of the program that ran the analysis.
    public init(methods: String = "",
                results: String = "",
                notes: [String] = [],
                analystNotes: String = "",
                dataVersion: String? = nil,
                dataModifiedAt: Date? = nil,
                appVersion: String? = nil) {
        self.methods = methods
        self.results = results
        self.notes = notes
        self.analystNotes = analystNotes
        self.dataVersion = dataVersion
        self.dataModifiedAt = dataModifiedAt
        self.appVersion = appVersion
    }
}
