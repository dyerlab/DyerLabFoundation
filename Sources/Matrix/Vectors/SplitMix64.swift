//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  SplitMix64.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 6/28/26.
//

/// A small seedable PRNG (SplitMix64) so permutation/resampling nulls are reproducible.
public struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    /// Creates a generator with the given seed.
    ///
    /// - Parameter seed: The 64-bit seed value; the same seed always produces the same sequence.
    public init(seed: UInt64) { self.state = seed }

    /// Advances the state and returns the next 64-bit pseudo-random value.
    ///
    /// - Returns: A pseudo-random `UInt64`.
    public mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
