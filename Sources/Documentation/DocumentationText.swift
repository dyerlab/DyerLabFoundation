//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationText.swift
//  Documentation
//
//  The readable text of an HTML page, for full-text search. Self-contained
//  Quarto pages carry their scripts, styles and images inline, so those are
//  dropped before the tags are, and what's left is folded to lower case
//  without diacritics so "wahlund" finds "Wahlund" and "hardy weinberg"
//  finds "Hardy–Weinberg".
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Reduces HTML to searchable text.
public enum DocumentationText {

    /// Elements whose contents aren't read as text.
    private static let hiddenElements = ["script", "style", "svg", "noscript", "template"]

    /// The words of an HTML page, folded for searching.
    ///
    /// - Parameter html: The page's HTML.
    /// - Returns: Its text, folded by ``folded(_:)``, with runs of white space made single spaces.
    public static func plainText(fromHTML html: String) -> String {
        var text = html
        for element in hiddenElements {
            text = text.replacingOccurrences(of: "<\(element)\\b[^>]*>[\\s\\S]*?</\(element)>", with: " ",
                                             options: [.regularExpression, .caseInsensitive])
        }
        text = text.replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        text = decodingEntities(text)
        return folded(text)
    }

    /// Text folded for matching: lower case, without diacritics, dashes as spaces, white space collapsed.
    ///
    /// - Parameter text: The text to fold.
    /// - Returns: The folded text.
    public static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .replacingOccurrences(of: "[\\-‐‑‒–—]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// The common named entities and all numeric ones, decoded.
    private static func decodingEntities(_ text: String) -> String {
        let named = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'",
                     "&apos;": "'", "&ndash;": "–", "&mdash;": "—", "&rsquo;": "’", "&lsquo;": "‘",
                     "&rdquo;": "”", "&ldquo;": "“"]
        var text = text
        for (entity, character) in named {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        guard text.contains("&#") else { return text }
        let pattern = #/&#(x?)([0-9A-Fa-f]+);/#
        return text.replacing(pattern) { match in
            let radix = match.output.1.isEmpty ? 10 : 16
            guard let code = UInt32(match.output.2, radix: radix), let scalar = Unicode.Scalar(code) else {
                return " "
            }
            return String(Character(scalar))
        }
    }
}
