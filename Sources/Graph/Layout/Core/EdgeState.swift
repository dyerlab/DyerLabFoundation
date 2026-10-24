//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  EdgeState.swift
//  Graph
//
//  Per-edge state for activation and smooth topology transitions.
//
//  Created by Rodney Dyer on 2026.06.22.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
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
        alpha * baseStiffness
    }
}
