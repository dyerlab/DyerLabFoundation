//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  String+NaturalSort.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 7/13/26.
//

import Foundation

/// Numeric-aware string comparison for researcher-facing identifiers (sample
/// IDs, stratum names, contig names, ...) whose values mix numeric and
/// non-numeric codes (e.g. "9", "12", "88", "SFr", "Const"). Plain
/// lexicographic comparison orders these as "12" < "2" < "88"; this orders
/// them the way a person expects, matching Finder's filename sort.
public extension String {

    /// Compares two strings treating embedded digit runs as numbers rather than
    /// character sequences, so `"9" < "12" < "88"` instead of `"12" < "88" < "9"`.
    func naturalCompare(_ other: String) -> ComparisonResult {
        self.compare(other, options: [.numeric, .caseInsensitive])
    }
}

public extension Sequence where Element == String {

    /// Sorts strings in natural (numeric-aware) order.
    func naturalSorted() -> [String] {
        sorted { $0.naturalCompare($1) == .orderedAscending }
    }
}

public extension Sequence {

    /// Sorts elements by a `String` key path in natural (numeric-aware) order.
    func naturalSorted(by keyPath: KeyPath<Element, String>) -> [Element] {
        sorted { $0[keyPath: keyPath].naturalCompare($1[keyPath: keyPath]) == .orderedAscending }
    }
}
