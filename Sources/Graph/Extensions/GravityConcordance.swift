//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GravityConcordance.swift
//  Graph
//
//  How a population's source-sink role compares between two graphs, gstudio's
//  gravity_congruence() `concordance` column. Raw values match R's labels.
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// Whether a population plays the same source-sink role in two graphs.
public enum GravityConcordance: String, Sendable, Hashable, CaseIterable {
    /// A source in both graphs (S₁, S₂ > 0).
    case source
    /// A sink in both graphs (S₁, S₂ < 0).
    case sink
    /// A source in one graph and a sink in the other.
    case discordant
    /// S = 0 in either graph (isolated, or in a two-node component), so it has no direction to compare.
    case neutral

    /// Classifies a population from its scores.
    ///
    /// - Parameters:
    ///   - s1: Its source-sink score in the first graph.
    ///   - s2: Its score in the second.
    /// - Returns: The concordance; scores within 10⁻¹² of zero count as zero.
    public init(_ s1: Double, _ s2: Double) {
        let tiny = 1e-12
        if abs(s1) < tiny || abs(s2) < tiny { self = .neutral }
        else if s1 > 0 && s2 > 0 { self = .source }
        else if s1 < 0 && s2 < 0 { self = .sink }
        else { self = .discordant }
    }
}
