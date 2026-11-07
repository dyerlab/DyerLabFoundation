//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RLiteral.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Formats values as R source, in the spaced style of the rest of the generated code.
enum RLiteral {

    /// The longest generated line, unless one quoted string is longer on its own.
    static let lineWidth = 80

    /// R's reserved words, which can't name a column without backticks.
    private static let reservedWords: Set<String> = [
        "if", "else", "repeat", "while", "function", "for", "next", "break", "TRUE", "FALSE", "NULL", "Inf", "NaN",
        "NA", "NA_integer_", "NA_real_", "NA_complex_", "NA_character_",
    ]

    /// Formats a number.
    ///
    /// - Parameters:
    ///   - value: The value, or `nil` for a missing one.
    ///   - digits: The number of significant digits to keep.
    /// - Returns: An R numeric literal, `NA`, `NaN`, `Inf` or `-Inf`.
    static func number(_ value: Double?, digits: Int) -> String {
        guard let value else { return "NA" }
        if value.isNaN { return "NaN" }
        if value.isInfinite { return value < 0 ? "-Inf" : "Inf" }
        return String(format: "%.\(digits)g", value)
    }

    /// Quotes a string so it is valid in both R and the `#|` options' YAML.
    ///
    /// - Parameter text: The text, which is collapsed onto one line.
    /// - Returns: The double-quoted, escaped string.
    static func quoted(_ text: String) -> String {
        let escaped = singleLine(text)
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    /// Collapses runs of whitespace, including newlines, to single spaces.
    ///
    /// - Parameter text: The text.
    /// - Returns: The text on one line.
    static func singleLine(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Formats a column name, in backticks if R wouldn't otherwise read it as a name.
    ///
    /// - Parameter name: The column's name.
    /// - Returns: The name as R source.
    static func name(_ name: String) -> String {
        let isLetter = { (character: Character) in character.isASCII && character.isLetter }
        let isDigit = { (character: Character) in character.isASCII && character.isNumber }
        let body = name.allSatisfy { isLetter($0) || isDigit($0) || $0 == "." || $0 == "_" }
        let afterDot = name.dropFirst().first.map { !isDigit($0) } ?? true
        let start = name.first.map { isLetter($0) || ($0 == "." && afterDot) } ?? false
        if body && start && !reservedWords.contains(name) { return name }
        return "`\(name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`"))`"
    }

    /// Formats a `c()` call, wrapped if it won't fit on a line.
    ///
    /// - Parameters:
    ///   - items: The vector's values as R literals.
    ///   - prefix: The text before the call on its first line.
    ///   - suffix: The text after the call's closing parenthesis.
    /// - Returns: The R code.
    static func vector(_ items: [String], prefix: String, suffix: String = "") -> String {
        guard !items.isEmpty else { return "\(prefix)c()\(suffix)" }
        let line = "\(prefix)c( \(items.joined(separator: ", ")) )\(suffix)"
        guard line.count > lineWidth else { return line }

        var lines: [String] = []
        var current = ""
        for item in items {
            let next = current.isEmpty ? "    \(item)" : "\(current), \(item)"
            if next.count > lineWidth - 1, !current.isEmpty {
                lines.append(current)
                current = "    \(item)"
            } else {
                current = next
            }
        }
        lines.append(current)
        return "\(prefix)c(\n\(lines.joined(separator: ",\n"))\n  )\(suffix)"
    }
}
