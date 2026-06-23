//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  VectorBinning.swift
//
//  Reusable numeric binning/frequency on `Vector`. The charting layer's
//  histogram/frequency transforms are thin wrappers over these so the math
//  lives in the numeric core where any consumer can reach it.
//

import Foundation

public extension Vector {

    /// A single histogram bin.
    struct Bin: Sendable, Hashable {
        /// The midpoint of the bin's value range.
        public let center: Double
        /// The inclusive lower edge of the bin.
        public let lower: Double
        /// The exclusive upper edge of the bin.
        public let upper: Double
        /// The number of observations that fell in the bin.
        public let count: Int

        public init(center: Double, lower: Double, upper: Double, count: Int) {
            self.center = center
            self.lower = lower
            self.upper = upper
            self.count = count
        }
    }

    /// Bins the vector's values into equal-width bins spanning its range.
    ///
    /// - Parameter bins: The number of bins (clamped to at least 1).
    /// - Returns: One ``Bin`` per interval, in ascending order. An empty
    ///   vector yields no bins; a zero-variance vector yields a single bin
    ///   holding every value.
    func histogram(bins: Int = 10) -> [Bin] {
        guard !isEmpty else { return [] }
        let n = Swift.max(1, bins)

        let lo = self.min() ?? 0
        let hi = self.max() ?? 0
        let span = hi - lo

        guard span > 0 else {
            return [Bin(center: lo, lower: lo, upper: lo, count: count)]
        }

        let width = span / Double(n)
        var result: [Bin] = []
        result.reserveCapacity(n)
        for i in 0 ..< n {
            let lower = lo + Double(i) * width
            let upper = lower + width
            // The final bin includes its upper edge so the maximum is counted.
            let isLast = (i == n - 1)
            let hits = self.filter { $0 >= lower && (isLast ? $0 <= upper : $0 < upper) }.count
            result.append(Bin(center: lower + width / 2.0, lower: lower, upper: upper, count: hits))
        }
        return result
    }

    /// Counts observations falling on each integer bucket in `range`.
    ///
    /// Each value is rounded to the nearest integer; values outside `range`
    /// are ignored. Returns one count per bucket, in `range` order.
    func frequency(range: ClosedRange<Int>) -> [Int] {
        var counts = [Int: Int]()
        for bucket in range { counts[bucket] = 0 }
        for value in self {
            let bucket = Int(value.rounded())
            if range.contains(bucket) { counts[bucket, default: 0] += 1 }
        }
        return range.map { counts[$0] ?? 0 }
    }
}
