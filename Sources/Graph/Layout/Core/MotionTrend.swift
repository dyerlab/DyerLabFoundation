//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MotionTrend.swift
//  Graph
//
//  Created by Rodney Dyer on 2026.06.22.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// A rolling record of per-frame motion, used to estimate how many more frames
/// a layout needs to come to rest.
///
/// The estimate assumes motion decays roughly geometrically, which holds for
/// annealed force-directed layouts (motion ∝ temperature) and for
/// Kamada–Kawai's Newton steps near a minimum. It is fitted to the graph's own
/// recent behaviour rather than to any fixed rule, so it adapts to topologies
/// that settle much faster or slower than typical.
public struct MotionTrend: Sendable {
    /// Frames of history kept.
    public let window: Int
    private var samples: [Float] = []

    /// Creates an empty trend.
    ///
    /// - Parameter window: Frames of history to keep (default `30`, minimum `10`).
    public init(window: Int = 30) {
        self.window = max(window, 10)
    }

    /// Records one frame's largest per-node move.
    ///
    /// - Parameter maxDisplacement: The largest distance any node moved this frame.
    public mutating func record(_ maxDisplacement: Float) {
        samples.append(maxDisplacement)
        if samples.count > window { samples.removeFirst(samples.count - window) }
    }

    /// Clears the history (on reset, resume or algorithm change).
    public mutating func reset() {
        samples.removeAll(keepingCapacity: true)
    }

    /// Estimated further frames until motion falls below `threshold`, or `nil`
    /// if there is too little history or motion is not decaying.
    ///
    /// - Parameter threshold: The per-frame displacement treated as "at rest".
    /// - Returns: The estimated frame count, or `nil`.
    public func framesToRest(threshold: Float) -> Int? {
        guard samples.count >= 10, threshold > 0 else { return nil }
        // Average a few frames at each end: per-frame maxima are noisy.
        let span = 5
        let early = samples.prefix(span).reduce(0, +) / Float(span)
        let late = samples.suffix(span).reduce(0, +) / Float(span)
        guard late > threshold else { return 0 }
        guard early > 0 else { return nil }
        let rate = pow(late / early, 1 / Float(samples.count - span))
        guard rate.isFinite, rate < 0.999 else { return nil }
        return Int((log(threshold / late) / log(rate)).rounded(.up))
    }
}
