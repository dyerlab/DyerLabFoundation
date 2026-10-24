//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RMersenneTwister.swift
//  Matrix
//
//  A Mersenne-Twister RNG that reproduces R's `set.seed()` + default sampler
//  bit-for-bit, so resampling ports (randomize_graph, the asymmetry nulls,
//  permute_popgraph) can be tested for exact numerical identity against R
//  rather than only statistically.
//
//  Matches R >= 3.6 with the default RNGkind: "Mersenne-Twister" / "Inversion" /
//  "Rejection". Verified against `set.seed(n); runif(...)` / `sample(...)`.
//
//  Created by Rodney Dyer on 2026.09.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// A Mersenne-Twister pseudo-random generator seeded exactly as R's
/// `set.seed(Int)` seeds it, exposing R's `unif_rand()`, `R_unif_index()`, and
/// `sample()`-without-replacement so Swift resampling can be compared to R
/// output value-for-value.
///
/// ```swift
/// var rng = RMersenneTwister(seed: 42)
/// rng.permutation(10)          // == R: set.seed(42); sample(10)
/// ```
public struct RMersenneTwister: RandomNumberGenerator {

    private static let n = 624
    private static let m = 397
    private static let matrixA: UInt32 = 0x9908_b0df
    private static let upperMask: UInt32 = 0x8000_0000
    private static let lowerMask: UInt32 = 0x7fff_ffff

    /// `mt[0..623]` is the state vector; `mti` is the read position.
    private var mt = [UInt32](repeating: 0, count: 624)
    private var mti = 625

    /// Seeds the generator the way R's `set.seed(seed)` does: 50 warm-up steps
    /// of the `69069·x + 1` LCG, then one LCG step per state word, then R's
    /// `FixupSeeds` (which forces `mti = 624`, i.e. "regenerate on first draw").
    ///
    /// - Parameter seed: The value passed to R's `set.seed()`.
    public init(seed: Int) {
        var s = UInt32(truncatingIfNeeded: seed)
        for _ in 0..<50 { s = 69069 &* s &+ 1 }
        // R fills i_seed[0..624]; i_seed[0] is mti (immediately overwritten by
        // FixupSeeds), i_seed[1..624] is the state.
        s = 69069 &* s &+ 1               // i_seed[0], discarded
        for k in 0..<Self.n {
            s = 69069 &* s &+ 1
            mt[k] = s
        }
        mti = Self.n                       // FixupSeeds(initial = TRUE)
    }

    /// One raw 32-bit Mersenne-Twister draw (tempered), matching R's
    /// `MT_genrand()` integer output before scaling.
    ///
    /// - Returns: The next tempered 32-bit output.
    public mutating func nextUInt32() -> UInt32 {
        if mti >= Self.n {
            let mag01: [UInt32] = [0, Self.matrixA]
            var kk = 0
            while kk < Self.n - Self.m {
                let y = (mt[kk] & Self.upperMask) | (mt[kk + 1] & Self.lowerMask)
                mt[kk] = mt[kk + Self.m] ^ (y >> 1) ^ mag01[Int(y & 1)]
                kk += 1
            }
            while kk < Self.n - 1 {
                let y = (mt[kk] & Self.upperMask) | (mt[kk + 1] & Self.lowerMask)
                mt[kk] = mt[kk + (Self.m - Self.n)] ^ (y >> 1) ^ mag01[Int(y & 1)]
                kk += 1
            }
            let y = (mt[Self.n - 1] & Self.upperMask) | (mt[0] & Self.lowerMask)
            mt[Self.n - 1] = mt[Self.m - 1] ^ (y >> 1) ^ mag01[Int(y & 1)]
            mti = 0
        }

        var y = mt[mti]
        mti += 1
        y ^= y >> 11
        y ^= (y << 7) & 0x9d2c_5680
        y ^= (y << 15) & 0xefc6_0000
        y ^= y >> 18
        return y
    }

    /// R's `unif_rand()` for the Mersenne-Twister: the raw draw times `2⁻³²`,
    /// with R's `fixup()` nudging the result strictly inside `(0, 1)`.
    ///
    /// - Returns: A uniform draw strictly inside `(0, 1)`.
    public mutating func unifRand() -> Double {
        let scale = 2.3283064365386963e-10          // 1 / 2^32, R's constant
        let x = Double(nextUInt32()) * scale
        let i2_32m1 = 2.328306437080797e-10          // R's i2_32m1
        if x <= 0.0 { return 0.5 * i2_32m1 }
        if 1.0 - x <= 0.0 { return 1.0 - 0.5 * i2_32m1 }
        return x
    }

    /// R's `R_unif_index(dn)` under `sample.kind = "Rejection"` (the R ≥ 3.6
    /// default): rejection sampling of an integer in `0..<n` from the smallest
    /// enclosing power of two.
    ///
    /// - Parameter n: The exclusive upper bound.
    /// - Returns: An integer in `0..<n`, or `0` if `n` is not positive.
    public mutating func unifIndex(_ n: Int) -> Int {
        guard n > 0 else { return 0 }
        let bits = Int(ceil(log2(Double(n))))
        var dv: Int
        repeat { dv = rbits(bits) } while n <= dv
        return dv
    }

    private mutating func rbits(_ bits: Int) -> Int {
        var v: Int64 = 0
        var offset = 0
        while offset <= bits {
            let v1 = Int64(floor(unifRand() * 65536.0))
            v = 65536 &* v &+ v1
            offset += 16
        }
        let mask = (Int64(1) << Int64(bits)) - 1
        return Int(v & mask)
    }

    /// R's `sample.int(n, size, replace = FALSE, prob = NULL)` (partial
    /// Fisher–Yates), returning **0-based** indices in draw order.
    ///
    /// - Parameters:
    ///   - n: Population size (draw from `0..<n`).
    ///   - size: Number of draws (`<= n`); defaults to a full permutation.
    /// - Returns: `size` distinct indices in `0..<n`, in draw order.
    public mutating func sampleIndicesNoReplacement(n: Int, size: Int? = nil) -> [Int] {
        let k = size ?? n
        precondition(k <= n, "cannot draw \(k) without replacement from \(n)")
        var pool = Array(0..<n)
        var remaining = n
        var result = [Int]()
        result.reserveCapacity(k)
        for _ in 0..<k {
            let j = unifIndex(remaining)
            result.append(pool[j])
            remaining -= 1
            pool[j] = pool[remaining]
        }
        return result
    }

    /// R's `sample(n)` / `sample(1:n)`: a full random permutation of `1...n`.
    ///
    /// - Parameter n: The number of elements to permute.
    /// - Returns: The values `1...n` in random order.
    public mutating func permutation(_ n: Int) -> [Int] {
        sampleIndicesNoReplacement(n: n).map { $0 + 1 }
    }

    /// R's `sample(x, size, replace:)` for an arbitrary array — reorders/draws
    /// `x` by drawing indices exactly as R does.
    ///
    /// - Parameters:
    ///   - x: The values to draw from.
    ///   - size: Number of draws; defaults to `x.count`.
    ///   - replace: Whether to draw with replacement.
    /// - Returns: The drawn elements, in draw order.
    public mutating func sample<T>(_ x: [T], size: Int? = nil, replace: Bool = false) -> [T] {
        let k = size ?? x.count
        if replace {
            return (0..<k).map { _ in x[unifIndex(x.count)] }
        }
        return sampleIndicesNoReplacement(n: x.count, size: k).map { x[$0] }
    }

    // MARK: - RandomNumberGenerator

    /// Two 32-bit MT draws packed high-word first. Provided for
    /// `RandomNumberGenerator` conformance; R-parity code should use
    /// ``unifRand()`` / ``unifIndex(_:)`` / the `sample` helpers instead, since
    /// those are what R's algorithms consume.
    ///
    /// - Returns: 64 random bits.
    public mutating func next() -> UInt64 {
        let hi = UInt64(nextUInt32())
        let lo = UInt64(nextUInt32())
        return (hi << 32) | lo
    }
}
