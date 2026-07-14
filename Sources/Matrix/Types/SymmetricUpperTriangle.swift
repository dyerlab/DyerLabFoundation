//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  SymmetricUpperTriangle.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 7/14/26.
//

import Foundation

/// Packed storage for a symmetric N×N matrix with a zero diagonal, holding
/// only its upper triangle.
///
/// Shared low-level storage for any symmetric pairwise measure over `N`
/// items (distances, dissimilarities, accumulated squared differences, ...)
/// — the index arithmetic and accumulation are identical regardless of what
/// the values represent or what the items are, so that logic lives here
/// once instead of being reimplemented per measure.
public struct SymmetricUpperTriangle<Element>: Sendable where Element: Sendable {

    /// Number of items; the matrix is `count`×`count`.
    public let count: Int

    /// Upper triangle (i < j), row-major; size `count·(count−1)/2`.
    private var storage: [Element]

    @inline(__always)
    private func index(_ i: Int, _ j: Int) -> Int {
        // i < j
        i * count - i * (i + 1) / 2 + (j - i - 1)
    }

    /// Creates storage for `count` items, every off-diagonal entry set to `fill`.
    ///
    /// - Parameters:
    ///   - count: Number of items; must be ≥ 0.
    ///   - fill: The initial value for every off-diagonal entry.
    public init(count: Int, fill: Element) {
        self.count = count
        self.storage = [Element](repeating: fill, count: max(0, count * (count - 1) / 2))
    }
}

public extension SymmetricUpperTriangle where Element: AdditiveArithmetic {

    /// Symmetric read/write access; the diagonal always returns `.zero`.
    ///
    /// - Parameters:
    ///   - i: Row index (0..<count).
    ///   - j: Column index (0..<count).
    subscript(_ i: Int, _ j: Int) -> Element {
        get {
            if i == j { return .zero }
            let (a, b) = i < j ? (i, j) : (j, i)
            return storage[index(a, b)]
        }
        set {
            if i == j { return }
            let (a, b) = i < j ? (i, j) : (j, i)
            storage[index(a, b)] = newValue
        }
    }

    /// Creates a zero matrix for `count` items.
    ///
    /// - Parameter count: Number of items; must be ≥ 0.
    init(count: Int) {
        self.init(count: count, fill: .zero)
    }

    /// Adds another matrix's entries in place, element-wise.
    ///
    /// - Parameter other: A same-sized matrix.
    mutating func add(_ other: SymmetricUpperTriangle<Element>) {
        precondition(count == other.count, "SymmetricUpperTriangle.add: sizes must match")
        for k in storage.indices { storage[k] += other.storage[k] }
    }

    /// Subtracts another matrix's entries in place, element-wise.
    ///
    /// - Parameter other: A same-sized matrix.
    mutating func subtract(_ other: SymmetricUpperTriangle<Element>) {
        precondition(count == other.count, "SymmetricUpperTriangle.subtract: sizes must match")
        for k in storage.indices { storage[k] -= other.storage[k] }
    }
}

public extension SymmetricUpperTriangle where Element == Double {

    /// Extracts the values among an arbitrary subset of items into a new,
    /// smaller matrix — a scattered gather costs the same as a contiguous
    /// one, since storage is addressed by computed offset.
    ///
    /// - Parameter indices: Item indices (0..<count) to include, in the
    ///   order they should appear in the result.
    /// - Returns: A matrix of size `indices.count`, where result `[a, b]` is
    ///   `self[indices[a], indices[b]]`.
    func submatrix(indices: [Int]) -> SymmetricUpperTriangle<Double> {
        var result = SymmetricUpperTriangle<Double>(count: indices.count)
        for a in 0..<indices.count {
            for b in (a + 1)..<indices.count {
                result[a, b] = self[indices[a], indices[b]]
            }
        }
        return result
    }

    /// A dense N×N representation (symmetric, zero diagonal).
    func dense() -> [[Double]] {
        var d = [[Double]](repeating: [Double](repeating: 0.0, count: count), count: count)
        for i in 0..<count {
            for j in (i + 1)..<count {
                let v = self[i, j]
                d[i][j] = v
                d[j][i] = v
            }
        }
        return d
    }
}

extension SymmetricUpperTriangle: Equatable where Element: Equatable {}
