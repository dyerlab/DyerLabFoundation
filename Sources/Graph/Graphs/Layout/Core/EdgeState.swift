//
//  EdgeState.swift
//  MatrixStuff
//
//  Per-edge state for activation and smooth topology transitions.
//

import Matrix
import Foundation

/// Per-edge state for activation and transitions.
///
/// Indexed parallel to graph.edges array.
public struct EdgeState {
    /// Current activation level [0, 1].
    /// 0 = fully inactive (no force), 1 = fully active.
    public var alpha: Float

    /// Target activation level (for ramping).
    public var targetAlpha: Float

    /// Ramp speed (change in alpha per second).
    public var rampSpeed: Float

    /// Creates an edge state with the specified activation.
    ///
    /// - Parameters:
    ///   - alpha: Initial activation level
    ///   - targetAlpha: Target activation level
    ///   - rampSpeed: Ramp speed in units per second
    public init(alpha: Float = 1.0, targetAlpha: Float = 1.0, rampSpeed: Float = 2.0) {
        self.alpha = alpha
        self.targetAlpha = targetAlpha
        self.rampSpeed = rampSpeed
    }

    /// Updates alpha toward target over time.
    ///
    /// - Parameter deltaTime: Time step in seconds
    public mutating func update(deltaTime: Float) {
        if alpha < targetAlpha {
            alpha = min(targetAlpha, alpha + rampSpeed * deltaTime)
        } else if alpha > targetAlpha {
            alpha = max(targetAlpha, alpha - rampSpeed * deltaTime)
        }
    }

    /// Effective stiffness after activation scaling.
    ///
    /// - Parameter baseStiffness: Base stiffness value
    /// - Returns: Scaled stiffness
    public func effectiveStiffness(baseStiffness: Float) -> Float {
        return alpha * baseStiffness
    }
}

/// Manages edge activation states.
public class EdgeStateManager {
    /// Activation states for each edge.
    public var states: [EdgeState]

    /// Creates an edge state manager with the specified number of edges.
    ///
    /// - Parameters:
    ///   - edgeCount: Number of edges
    ///   - initialAlpha: Initial activation level for all edges
    public init(edgeCount: Int, initialAlpha: Float = 1.0) {
        self.states = Array(
            repeating: EdgeState(
                alpha: initialAlpha,
                targetAlpha: initialAlpha,
                rampSpeed: 2.0  // 0→1 in 0.5 seconds
            ),
            count: edgeCount
        )
    }

    /// Sets all edges to ramp toward target activation.
    ///
    /// - Parameters:
    ///   - target: Target activation level [0, 1]
    ///   - duration: Ramp duration in seconds
    public func rampAll(to target: Float, duration: Float) {
        guard !states.isEmpty && duration > 0 else { return }
        let speed = abs(target - states[0].alpha) / duration
        for i in 0..<states.count {
            states[i].targetAlpha = target
            states[i].rampSpeed = speed
        }
    }

    /// Ramps a specific edge to the target activation.
    ///
    /// - Parameters:
    ///   - index: Edge index
    ///   - target: Target activation level [0, 1]
    ///   - duration: Ramp duration in seconds
    public func ramp(index: Int, to target: Float, duration: Float) {
        guard index >= 0 && index < states.count && duration > 0 else { return }
        let speed = abs(target - states[index].alpha) / duration
        states[index].targetAlpha = target
        states[index].rampSpeed = speed
    }

    /// Updates all edge activations.
    ///
    /// - Parameter deltaTime: Time step in seconds
    public func updateAll(deltaTime: Float) {
        for i in 0..<states.count {
            states[i].update(deltaTime: deltaTime)
        }
    }

    /// Resets all edges to full activation immediately.
    public func resetAll() {
        for i in 0..<states.count {
            states[i].alpha = 1.0
            states[i].targetAlpha = 1.0
        }
    }

    /// Sets a specific edge to the given activation level immediately.
    ///
    /// - Parameters:
    ///   - index: Edge index
    ///   - alpha: Activation level [0, 1]
    public func setImmediate(index: Int, alpha: Float) {
        guard index >= 0 && index < states.count else { return }
        states[index].alpha = alpha
        states[index].targetAlpha = alpha
    }
}
