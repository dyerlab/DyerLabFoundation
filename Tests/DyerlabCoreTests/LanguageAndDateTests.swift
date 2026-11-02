//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  LanguageAndDateTests.swift
//  DyerlabCoreTests
//
//  Created by Rodney Dyer on 2026.10.28.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import DyerlabCore

@Suite("Double.sentimentEmoji")
struct SentimentEmojiTests {

    @Test("maps the ends and the middle of the scale")
    func endpoints() {
        #expect((-1.0).sentimentEmoji == "🤬")
        #expect(0.0.sentimentEmoji == "😶")
        #expect(1.0.sentimentEmoji == "😍")
    }

    @Test("clamps out-of-range and infinite scores", arguments: [1.19, 5.0, Double.infinity])
    func clampsHigh(score: Double) {
        #expect(score.sentimentEmoji == "😍")
        #expect((-score).sentimentEmoji == "🤬")
    }

    @Test("rounds to the nearest tenth, symmetrically")
    func rounding() {
        #expect(0.04.sentimentEmoji == "😶")
        #expect(0.06.sentimentEmoji == "😌")
        #expect((-0.06).sentimentEmoji == "😑")
    }

    @Test("returns an empty string for NaN instead of crashing")
    func nan() {
        #expect(Double.nan.sentimentEmoji == "")
    }
}

@Suite("String language extensions")
struct StringLanguageTests {

    @Test("counts words, sentences, and paragraphs")
    func counts() {
        let text = "The river was high. We saw two herons.\n\nThen it rained."
        #expect(text.words == 11)
        #expect(text.sentences == 3)
        #expect(text.paragraphs == 2)
    }

    @Test("blank lines don't add a negative sentence score")
    func blankLines() {
        let oneParagraph = "I love this beautiful place."
        let withBlank = oneParagraph + "\n\n" + oneParagraph
        #expect(withBlank.sentenceLevelSentiment.count == 2)
        #expect(abs(withBlank.meanSentenceSentiment - oneParagraph.meanSentenceSentiment) < 0.01)
    }

    @Test("empty and whitespace-only text has no sentences and a neutral mean")
    func emptyText() {
        for text in ["", "   \n "] {
            #expect(text.sentenceLevelSentiment.isEmpty)
            #expect(text.meanSentenceSentiment == 0)
            #expect(text.ARI == 0)
        }
    }

    @Test("scores clearly positive and negative text with the right sign")
    func sentimentSign() {
        #expect("I love this beautiful, wonderful place.".sentiment > 0)
        #expect("This is a terrible, awful, miserable day.".sentiment < 0)
    }

    @Test("firstWord returns the text before the first space")
    func firstWord() {
        #expect("Belonging score".firstWord == "Belonging")
        #expect("".firstWord == "")
    }

    @Test("languageTags skips punctuation")
    func tags() {
        let tags = "Herons, egrets!".languageTags(scheme: .lexicalClass)
        #expect(tags.map(\.word) == ["Herons", "egrets"])
    }
}

@Suite("Date day and month helpers")
struct DateBoundaryTests {

    let noon = Calendar.current.date(from: DateComponents(year: 2024, month: 2, day: 10, hour: 12))!

    @Test("endOfDay is one second before the next midnight")
    func dayBounds() {
        let nextMidnight = Calendar.current.date(byAdding: .day, value: 1, to: noon.startOfDay)!
        #expect(noon.endOfDay == nextMidnight.addingTimeInterval(-1))
    }

    @Test("onThisDay includes both ends of the day and excludes the next")
    func onThisDay() {
        #expect(noon.startOfDay.onThisDay(day: noon))
        #expect(noon.endOfDay.onThisDay(day: noon))
        #expect(!noon.endOfDay.addingTimeInterval(1).onThisDay(day: noon))
    }

    @Test("daysInMonth handles leap years")
    func daysInMonth() {
        #expect(noon.daysInMonth() == 29)
        #expect(noon.daysInMonth(2, 2023) == 28)
        #expect(noon.daysInMonth(12) == 31)
    }

    @Test("month boundaries")
    func monthBounds() {
        let comps = Calendar.current.dateComponents([.month, .day],
                                                    from: Date.endOfMonth(currentDate: noon))
        #expect(Date.startOfMonth(currentDate: noon).get(.day) == 1)
        #expect(comps.month == 2 && comps.day == 29)
    }

    @Test("randomDates are sorted and within range")
    func randomDates() {
        let dates = Date.randomDates(count: 50, days: 10)
        #expect(dates.count == 50)
        #expect(dates == dates.sorted())
        #expect(dates.allSatisfy { $0 <= .now && $0 >= Date(timeIntervalSinceNow: -10 * 86_400 - 1) })
    }
}

@Suite("String.csvQuoted")
struct CSVQuotedTests {

    @Test("quotes fields per RFC 4180")
    func quoting() {
        #expect("plain".csvQuoted == "\"plain\"")
        #expect("say \"hi\", ok".csvQuoted == "\"say \"\"hi\"\", ok\"")
    }
}
