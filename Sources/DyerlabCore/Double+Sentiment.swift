//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Double+Sentiment.swift
//  DyerlabCore
//
//  Created by Rodney Dyer on 2024.05.15.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

public extension Double {

    /// The 21 sentiment emoji, from most negative (-1.0) to most positive (1.0) in steps of 0.1.
    static let sentimentEmojis: [String] = [
        "🤬", "😡", "😠", "😤", "😫", "😣", "😔", "🙁", "😕", "😑",
        "😶",
        "😌", "🙂", "😊", "😋", "😄", "😆", "😏", "😎", "🤩", "😍"
    ]

    /// An emoji for a sentiment score from -1.0 (very negative) to 1.0 (very positive).
    ///
    /// The score is rounded to the nearest 0.1, with 😶 at 0. Scores outside
    /// -1.0...1.0 (including infinities) use the end emoji. Returns an empty
    /// string for `.nan`, which is what an empty set of scores averages to,
    /// so a missing score never shows as a real one.
    var sentimentEmoji: String {
        guard !isNaN else { return "" }
        let clamped = Swift.min(Swift.max(self, -1.0), 1.0)
        return Self.sentimentEmojis[Int((clamped * 10).rounded()) + 10]
    }
}
