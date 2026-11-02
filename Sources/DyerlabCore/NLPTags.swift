//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  NLPTags.swift
//  DyerlabCore
//
//  Created by Rodney Dyer on 2024.05.09.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import NaturalLanguage

/// A word paired with the tag `NLTagger` assigned to it.
///
/// Produced by ``Swift/String/languageTags(scheme:)``.
public struct NLPTags: Identifiable, Hashable, Sendable {

    // MARK: - Properties

    /// A unique identifier, so repeated words remain distinct in lists.
    public var id: UUID
    /// The word as it appears in the text.
    public var word: String
    /// The tag for the word, such as its lemma or part of speech.
    public var tag: NLTag?

    // MARK: - Initializers

    /// Creates a tagged word.
    /// - Parameters:
    ///   - word: The word as it appears in the text.
    ///   - tag: The tag for the word, if any.
    public init(word: String, tag: NLTag? = nil) {
        self.id = UUID()
        self.word = word
        self.tag = tag
    }
}

// MARK: - Conformance

extension NLPTags: CustomStringConvertible {
    /// `word: tag`, or just the word if it has no tag.
    public var description: String {
        if let tag { return "\(word): \(tag.rawValue)" }
        return word
    }
}
