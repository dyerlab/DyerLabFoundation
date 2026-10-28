//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  SettleDetector.swift
//  Graph
//
//  Detects when the layout simulation has settled (converged).
//
//  Created by Rodney Dyer on 2026.06.22.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import Foundation

/// Detects when the simulation has settled based on visible node motion.
///
/// The system is considered settled when the largest single-node move per frame
/// stays below a threshold for a specified number of consecutive frames.
///
/// This watches *motion*, not energy. A layout of a real, distance-weighted
/// graph rarely reaches zero energy: edge lengths that can't all be satisfied
/// in 2D leave permanent tension, so raw velocities level off far above zero
/// while annealing has already frozen the picture. Settling here means the
/// layout has stopped changing visibly, at whatever local minimum it found.
public class SettleDetector {
    /// Number of consecutive frames below threshold.
    private var consecutiveSettledFrames: Int = 0

    /// Largest per-node move per frame, in world units, still counted as still.
    public let threshold: Float

    /// Number of consecutive frames required to declare settled.
    public let requiredFrames: Int

    /// Creates a new settle detector.
    ///
    /// - Parameters:
    ///   - threshold: Largest per-node move per frame, in world units (default: 0.05)
    ///   - requiredFrames: Consecutive frames required (default: 10)
    public init(threshold: Float = 0.05, requiredFrames: Int = 10) {
        self.threshold = threshold
        self.requiredFrames = requiredFrames
    }

    /// Checks if system has settled.
    ///
    /// - Parameter maxDisplacement: Largest single-node move this frame
    ///   (``LayoutState/maxDisplacement``)
    /// - Returns: True if settled for required frame count
    public func update(maxDisplacement: Float) -> Bool {
        if maxDisplacement < threshold {
            consecutiveSettledFrames += 1
        } else {
            consecutiveSettledFrames = 0
        }
        return consecutiveSettledFrames >= requiredFrames
    }

    /// Resets detector (call when system is disturbed).
    public func reset() {
        consecutiveSettledFrames = 0
    }

    /// Returns the current number of consecutive settled frames.
    public var settledFrameCount: Int {
        consecutiveSettledFrames
    }

    /// Returns progress toward settling (0.0 to 1.0).
    public var settleProgress: Float {
        Float(consecutiveSettledFrames) / Float(requiredFrames)
    }
}
