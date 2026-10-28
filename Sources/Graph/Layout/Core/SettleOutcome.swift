//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  SettleOutcome.swift
//  Graph
//
//  Created by Rodney Dyer on 2026.06.22.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

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
