//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Array+Double.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2024.04.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

public extension Array where Element == Double {

    /// Sum of the elements in the aray
    ///
    /// - Returns: The sum, or `0` for an empty array.
    func sum() -> Double {
        self.reduce(0, +)
    }

    /// Mean of the values
    ///
    /// - Returns: The arithmetic mean, or `.nan` for an empty array.
    func mean() -> Double {
        self.sum() / Double(self.count)
    }

    /// Median of the arrays values
    ///
    /// - Returns: The median, or `.nan` for an empty array.
    func median() -> Double {
        guard !self.isEmpty else { return .nan }
        let vals = self.sorted()
        if vals.count % 2 == 0 {
            return Double((vals[(vals.count / 2)] + vals[(vals.count / 2) - 1])) / 2
        } else {
            return Double(vals[(vals.count - 1) / 2])
        }
    }

    /// The `p`-quantile (`0...1`), linearly interpolated between order statistics.
    ///
    /// - Parameter p: The quantile, in `0...1`.
    /// - Returns: The interpolated quantile, or `.nan` for an empty array.
    func quantile(_ p: Double) -> Double {
        guard !self.isEmpty else { return .nan }
        let vals = self.sorted()
        guard vals.count > 1 else { return vals[0] }
        let rank = p * Double(vals.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = Int(rank.rounded(.up))
        guard lower != upper else { return vals[lower] }
        let fraction = rank - Double(lower)
        return vals[lower] + fraction * (vals[upper] - vals[lower])
    }

    /// The sample standard deviation
    ///
    /// - Returns: The standard deviation, or `.nan` with fewer than two values.
    func sd() -> Double {
        guard self.count > 1 else { return .nan }
        let mean = self.mean()
        let v = self.reduce(0, { $0 + ($1-mean)*($1-mean) })
        return sqrt(v / (Double(self.count) - 1))
    }

    /// Take double and return dictionary of counts
    var discretize: [Double: Int] {
        var ret = [Double: Int]()
        for value in self {
            ret[value, default: 0] += 1
        }
        return ret
    }

}
