//
//  SettleDetector.swift
//  DyerLabFoundation
//
//  Detects when the layout simulation has settled (converged).
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
        return consecutiveSettledFrames
    }

    /// Returns progress toward settling (0.0 to 1.0).
    public var settleProgress: Float {
        return Float(consecutiveSettledFrames) / Float(requiredFrames)
    }
}

// MARK: - Settle outcome

/// How a layout run ended.
///
/// Both outcomes are local minima at best; neither algorithm finds a global
/// minimum for non-trivial topologies. The distinction is whether the layout
/// had *stopped visibly changing* when it ended, or was cut off by its budget
/// while parts of it were still rearranging.
public enum SettleOutcome: Equatable, Sendable {
    /// Motion fell below ``LayoutConfiguration/settleThreshold``.
    case atRest

    /// The iteration budget ran out while nodes were still visibly moving.
    ///
    /// - Parameters:
    ///   - maxDisplacement: Largest per-node move in the final frame, world units.
    ///   - suggestedBudget: A budget, in the units of
    ///     ``LayoutOrchestrator/iterationBudget``, expected to let the layout come
    ///     to rest, estimated from how fast motion was decaying. `nil` when
    ///     motion was not decaying, so more iterations alone are unlikely to
    ///     help (try other settings).
    case stoppedStillMoving(maxDisplacement: Float, suggestedBudget: Int?)
}

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

    public init(window: Int = 30) {
        self.window = max(window, 10)
    }

    /// Records one frame's largest per-node move.
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
