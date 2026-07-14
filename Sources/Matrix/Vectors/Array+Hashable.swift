//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  Array+Hashable.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 6/5/25.
//

/// Extensions for arrays of hashable elements to support frequency counting.
extension Array where Element: Hashable {

    /// Computes a frequency table of elements in the array.
    ///
    /// This method counts the occurrences of each unique element and returns
    /// a dictionary mapping each element to its count (as a `Double`).
    ///
    /// Named distinctly from `Vector.histogram(bins:)` (`VectorBinning.swift`)
    /// on purpose: `Vector` is `typealias Vector = [Double]`, and `Double`
    /// conforms to `Hashable`, so a zero-argument `histogram()` here would be
    /// ambiguous against `Vector`'s own `histogram(bins:)` (which has a
    /// defaulted parameter, making it callable with zero arguments too) at
    /// every call site operating on a `Vector`.
    ///
    /// - Returns: A dictionary where keys are unique elements and values are occurrence counts.
    public func valueCounts() -> [Element: Double] {
        return self.reduce(into: [:]) { counts, elem in counts[elem, default: 0.0] += 1.0 }
    }

}
