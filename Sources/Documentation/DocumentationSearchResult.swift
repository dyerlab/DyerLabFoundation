//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationSearchResult.swift
//  Documentation
//
//  One entry the help search found, with where it sits in the outline and
//  whether the match was in its title or only in its page's text.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// An entry that matched a help search.
public struct DocumentationSearchResult: Hashable, Identifiable, Sendable {

    /// Where the match was found.
    public enum Match: Int, Comparable, Sendable {
        /// The entry's title, keywords or summary.
        case title
        /// Only the text of the entry's page.
        case text

        /// Title matches sort first.
        public static func < (lhs: Match, rhs: Match) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// The entry found.
    public let entry: DocumentationEntry
    /// The titles of the entries above it, outermost first.
    public let path: [String]
    /// Where the match was found.
    public let match: Match

    /// The entry's id.
    public var id: DocumentationEntry.ID { entry.id }

    /// Creates a result.
    ///
    /// - Parameters:
    ///   - entry: The entry found.
    ///   - path: The titles of the entries above it.
    ///   - match: Where the match was found.
    public init(entry: DocumentationEntry, path: [String], match: Match) {
        self.entry = entry
        self.path = path
        self.match = match
    }
}
