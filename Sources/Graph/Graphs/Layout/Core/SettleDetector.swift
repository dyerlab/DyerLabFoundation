//
//  SettleDetector.swift
//  MatrixStuff
//
//  Detects when the layout simulation has settled (converged).
//

import Matrix
import Foundation

/// Detects when the simulation has settled based on kinetic energy monitoring.
///
/// The system is considered settled when kinetic energy remains below a threshold
/// for a specified number of consecutive frames.
public class SettleDetector {
    /// Number of consecutive frames below threshold.
    private var consecutiveSettledFrames: Int = 0

    /// Kinetic energy threshold for settle detection.
    public let threshold: Float

    /// Number of consecutive frames required to declare settled.
    public let requiredFrames: Int

    /// Creates a new settle detector.
    ///
    /// - Parameters:
    ///   - threshold: Kinetic energy threshold (default: 0.01)
    ///   - requiredFrames: Consecutive frames required (default: 10)
    public init(threshold: Float = 0.01, requiredFrames: Int = 10) {
        self.threshold = threshold
        self.requiredFrames = requiredFrames
    }

    /// Checks if system has settled.
    ///
    /// - Parameter kineticEnergy: Current kinetic energy
    /// - Returns: True if settled for required frame count
    public func update(kineticEnergy: Float) -> Bool {
        if kineticEnergy < threshold {
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
        return consecutiveSettledFrames
    }

    /// Returns progress toward settling (0.0 to 1.0).
    public var settleProgress: Float {
        return Float(consecutiveSettledFrames) / Float(requiredFrames)
    }
}
