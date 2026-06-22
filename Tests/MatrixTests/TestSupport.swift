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
//  TestSupport.swift
//  MatrixStuffTests
//
//  Shared helpers for numerical tests: tolerant comparisons and a
//  deterministic random number generator for reproducible layout tests.
//

import Foundation
import Foundation

// MARK: - Approximate Comparison

/// Compares two scalars with a combined absolute/relative tolerance.
///
/// Numerical results from Accelerate (`vDSP`, BLAS, LAPACK) are not guaranteed to be
/// bit-identical to the same computation done with Swift scalar math, so tests of
/// computed values should compare with a tolerance rather than `==`.
func isApprox(_ a: Double, _ b: Double, tolerance: Double = 1e-9) -> Bool {
    if a == b { return true }
    if a.isNaN || b.isNaN { return false }
    let diff = abs(a - b)
    if diff <= tolerance { return true }                       // absolute
    return diff <= tolerance * Swift.max(abs(a), abs(b))       // relative
}

/// Element-wise tolerant comparison of two vectors.
func isApprox(_ a: [Double], _ b: [Double], tolerance: Double = 1e-9) -> Bool {
    guard a.count == b.count else { return false }
    return zip(a, b).allSatisfy { isApprox($0, $1, tolerance: tolerance) }
}

/// Tolerant comparison of two `Float` values.
func isApprox(_ a: Float, _ b: Float, tolerance: Float = 1e-5) -> Bool {
    if a == b { return true }
    if a.isNaN || b.isNaN { return false }
    let diff = abs(a - b)
    if diff <= tolerance { return true }
    return diff <= tolerance * Swift.max(abs(a), abs(b))
}

// MARK: - Deterministic RNG

/// A small, fully deterministic random number generator (SplitMix64).
///
/// Seeding with a fixed value makes layout tests — which depend on randomized
/// initial node positions — reproducible across runs and machines.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
