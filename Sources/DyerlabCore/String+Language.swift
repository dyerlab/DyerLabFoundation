//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  String+Language.swift
//  DyerlabCore
//
//  Created by Rodney Dyer on 2024.05.09.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  String extensions built on the NaturalLanguage framework: sentiment
//  scoring, word/sentence/paragraph counts, a readability index, and
//  word-level tagging. Originally written for FOTJ and EcoConnect, where
//  they analyze free-text journal responses.
//

import Foundation
import NaturalLanguage

public extension String {

    // MARK: - Sentiment

    /// The sentiment score of the whole string, from -1.0 (negative) to 1.0 (positive).
    ///
    /// Scored as a single paragraph with `NLTagger`. Returns `0` if no score is available.
    var sentiment: Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = self
        let (tag, _) = tagger.tag(at: startIndex, unit: .paragraph, scheme: .sentimentScore)
        return Double(tag?.rawValue ?? "0") ?? 0
    }

    /// The ``sentiment`` of each sentence, in order.
    ///
    /// Scoring by sentence keeps one strongly worded sentence from dominating
    /// a long passage. Returns an empty array for text with no sentences
    /// (such as an empty or whitespace-only string).
    var sentenceLevelSentiment: [Double] {
        var ret = [Double]()
        enumerate(unit: .sentence) { range in
            ret.append(String(self[range]).sentiment)
        }
        return ret
    }

    /// The mean of ``sentenceLevelSentiment``, or `0` (neutral) if the text has no sentences.
    ///
    /// Use this rather than `sentenceLevelSentiment.mean()` when the result is
    /// stored or displayed, because the mean of an empty array is `.nan`.
    var meanSentenceSentiment: Double {
        let scores = sentenceLevelSentiment
        return scores.isEmpty ? 0 : scores.mean()
    }

    // MARK: - Counts

    /// The text before the first space, or an empty string if there is none.
    var firstWord: String {
        split(separator: " ").first.map(String.init) ?? ""
    }

    /// The number of words, using `NLTokenizer`.
    var words: Int { count(unit: .word) }

    /// The number of sentences, using `NLTokenizer`.
    var sentences: Int { count(unit: .sentence) }

    /// The number of paragraphs, using `NLTokenizer`.
    var paragraphs: Int { count(unit: .paragraph) }

    // MARK: - Readability

    /// The Automated Readability Index, an estimate of the U.S. grade level
    /// needed to understand the text.
    ///
    /// Computed as `4.71 × (characters / words) + 0.5 × (words / sentences) − 21.43`.
    /// Returns `0` if the text has no words or sentences.
    /// See <https://en.wikipedia.org/wiki/Automated_readability_index>.
    var ARI: Double {
        let sentences = Double(self.sentences)
        if sentences == 0 { return 0.0 }

        var characters = 0.0
        var words = 0.0
        enumerate(unit: .word) { range in
            words += 1.0
            characters += Double(self[range].count)
        }
        return words == 0 ? 0.0 : (4.71 * (characters / words)) + (0.5 * (words / sentences)) - 21.43
    }

    // MARK: - Tagging

    /// Tags each word with `scheme`, skipping punctuation, whitespace, and words with no tag.
    ///
    /// For example, `.lemma` gives each word's dictionary form (used for word
    /// clouds), and `.lexicalClass` gives its part of speech.
    /// - Parameter scheme: The tag scheme to apply.
    /// - Returns: One ``NLPTags`` per tagged word, in order.
    func languageTags(scheme: NLTagScheme) -> [NLPTags] {
        var ret = [NLPTags]()
        let tagger = NLTagger(tagSchemes: [scheme])
        tagger.string = self
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther]
        tagger.enumerateTags(in: startIndex ..< endIndex, unit: .word, scheme: scheme, options: options) { tag, range in
            if let tag {
                ret.append(NLPTags(word: String(self[range]), tag: tag))
            }
            return true
        }
        return ret
    }

    // MARK: - Helpers

    /// Calls `body` with the range of each token of the given unit, skipping blank tokens.
    ///
    /// `NLTokenizer` returns whitespace-only tokens for blank lines (such as the
    /// `"\n"` between paragraphs). They are skipped so they aren't counted as
    /// sentences or paragraphs, and because `NLTagger` gives whitespace a
    /// strongly negative sentiment score (about -0.6), which would skew the mean.
    private func enumerate(unit: NLTokenUnit, _ body: (Range<String.Index>) -> Void) {
        let tokenizer = NLTokenizer(unit: unit)
        tokenizer.string = self
        tokenizer.enumerateTokens(in: startIndex ..< endIndex) { range, _ in
            if !self[range].allSatisfy(\.isWhitespace) {
                body(range)
            }
            return true
        }
    }

    /// The number of tokens of the given unit.
    private func count(unit: NLTokenUnit) -> Int {
        var ret = 0
        enumerate(unit: unit) { _ in ret += 1 }
        return ret
    }
}
