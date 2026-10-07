//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  RankCorrelation.swift
//  DyerLabFoundation
//
//  Average ranks and Spearman's rank correlation — R's `rank(ties.method =
//  "average")` and `cor(method = "spearman")`. Added for `Graph`'s
//  `SourceSinkTest` (a port of gstudio's `source_sink_test()`).
//

import Foundation

/// Ranks of `x` (1-based), with tied values given the mean of the ranks they
/// span — R's `rank(x, ties.method = "average")`.
public func averageRanks(_ x: Vector) -> Vector {
    let order = x.indices.sorted { x[$0] < x[$1] }
    var ranks = Vector(repeating: 0.0, count: x.count)
    var start = 0
    while start < order.count {
        var end = start
        while end + 1 < order.count && x[order[end + 1]] == x[order[start]] { end += 1 }
        let rank = Double(start + end + 2) / 2.0
        for position in start...end { ranks[order[position]] = rank }
        start = end + 1
    }
    return ranks
}

/// Spearman's rank correlation: the Pearson correlation of the average ranks —
/// R's `cor(x, y, method = "spearman")`.
///
/// - Returns: `ρ ∈ [-1, 1]`, or `.nan` if the vectors differ in length, have
///   fewer than two elements, or either is constant.
public func spearmanCorrelation(_ x: Vector, _ y: Vector) -> Double {
    guard x.count == y.count, x.count > 1 else { return .nan }
    return pearsonCorrelation(averageRanks(x), averageRanks(y))
}
