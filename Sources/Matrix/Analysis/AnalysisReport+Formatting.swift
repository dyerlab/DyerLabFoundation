//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AnalysisReport+Formatting.swift
//  Matrix
//
//  Number formatting shared by every analysis's report values, so all
//  reports read alike: statistics to three significant figures (four
//  decimals for small values), p-values to three decimals.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension AnalysisReport {

    /// A statistic for running text.
    ///
    /// - Parameter value: The value.
    /// - Returns: Three significant figures (at most four decimals), or
    ///   `"NA"` for a non-finite value.
    public static func number(_ value: Double) -> String {
        guard value.isFinite else { return "NA" }
        if value == 0 { return "0" }
        let magnitude = abs(value)
        if magnitude >= 1000 { return String(format: "%.0f", value) }
        let decimals = min(4, max(0, 2 - Int(floor(log10(magnitude)))))
        return String(format: "%.\(decimals)f", value)
    }

    /// A whole count for running text.
    ///
    /// - Parameter value: The count.
    /// - Returns: The count with thousands separators.
    public static func count(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    /// A p-value clause for running text.
    ///
    /// - Parameter value: The p-value, or `nil` if untested.
    /// - Returns: `"P = 0.012"`, or `"not tested"`.
    public static func pValue(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "not tested" }
        return "P = " + String(format: "%.3f", value)
    }

    /// An interval for running text.
    ///
    /// - Parameter interval: The interval, or `nil`.
    /// - Returns: `"0.12–0.34"`, or `"NA"`.
    public static func interval(_ interval: ClosedRange<Double>?) -> String {
        guard let interval else { return "NA" }
        return number(interval.lowerBound) + "–" + number(interval.upperBound)
    }

    /// The sentence describing a permutation test, for Methods.
    ///
    /// - Parameters:
    ///   - options: The run's options.
    ///   - what: What was permuted, e.g. `"individuals among groups"`.
    /// - Returns: A sentence, or one saying significance was not tested.
    public static func permutationSentence(_ options: AnalysisOptions, permuting what: String) -> String {
        guard options.iterations > 0 else { return "Significance was not tested." }
        return "Significance was assessed with \(count(options.iterations)) random permutations of \(what) "
            + "(random seed \(options.seed))."
    }

    /// An axis-style label for use mid-sentence: its first letter lowercased
    /// ("Separation (km)" → "separation (km)"), unless its first word is an
    /// acronym ("cGD", "PCA").
    ///
    /// - Parameter label: The label.
    /// - Returns: The label for running text.
    public static func sentenceCase(_ label: String) -> String {
        guard let first = label.first else { return label }
        let word = label.prefix { !$0.isWhitespace }
        if word.dropFirst().contains(where: \.isUppercase) { return label }
        return first.lowercased() + label.dropFirst()
    }
}
