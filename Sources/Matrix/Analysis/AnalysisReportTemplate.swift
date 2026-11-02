//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AnalysisReportTemplate.swift
//  Matrix
//
//  Manuscript text with `{key}` placeholders. Each analysis ships a default
//  template; the values come from the analysis (its data and options, for
//  Methods) and its outcome (the estimates, for Results), so an app can also
//  render the same values into its own wording. A placeholder with no value
//  is left in the text as `{key}`, so a gap is visible rather than silent.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// Methods and Results text with `{key}` placeholders.
public struct AnalysisReportTemplate: Sendable, Equatable, Hashable {

    /// The Methods passage.
    public let methods: String

    /// The Results passage.
    public let results: String

    /// Creates a template.
    ///
    /// - Parameters:
    ///   - methods: The Methods passage, with `{key}` placeholders.
    ///   - results: The Results passage, with `{key}` placeholders.
    public init(methods: String, results: String) {
        self.methods = methods
        self.results = results
    }

    /// Replaces each `{key}` in `text` with `values[key]`.
    ///
    /// - Parameters:
    ///   - text: Text with `{key}` placeholders.
    ///   - values: The value for each key.
    /// - Returns: The filled text; a placeholder without a value is left as is.
    public static func fill(_ text: String, with values: [String: String]) -> String {
        var output = ""
        var rest = text[...]
        while let open = rest.firstIndex(of: "{") {
            guard let close = rest[open...].firstIndex(of: "}") else { break }
            output += rest[..<open]
            let key = String(rest[rest.index(after: open)..<close])
            output += values[key] ?? "{\(key)}"
            rest = rest[rest.index(after: close)...]
        }
        return output + rest
    }

    /// The placeholder keys used in `text`, in order of first appearance.
    ///
    /// - Parameter text: Text with `{key}` placeholders.
    /// - Returns: The keys.
    public static func keys(in text: String) -> [String] {
        var keys: [String] = []
        var rest = text[...]
        while let open = rest.firstIndex(of: "{"), let close = rest[open...].firstIndex(of: "}") {
            let key = String(rest[rest.index(after: open)..<close])
            if !keys.contains(key) { keys.append(key) }
            rest = rest[rest.index(after: close)...]
        }
        return keys
    }
}
