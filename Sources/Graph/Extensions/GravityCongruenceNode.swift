//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GravityCongruenceNode.swift
//  Graph
//
//  One row of gstudio's gravity_congruence() `nodes` table.
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// A population's genetic gravity in each of two graphs.
public struct GravityCongruenceNode: Sendable, Hashable, Identifiable {
    /// The population.
    public let stratum: String
    /// Its source-sink score in the first graph.
    public let s1: Double
    /// Its source-sink score in the second graph.
    public let s2: Double
    /// Its gravity in the first graph.
    public let gravity1: Double
    /// Its gravity in the second graph.
    public let gravity2: Double
    /// Its degree in the first graph.
    public let degree1: Int
    /// Its degree in the second graph.
    public let degree2: Int

    /// Whether it plays the same source-sink role in both.
    public var concordance: GravityConcordance { GravityConcordance(s1, s2) }

    /// The population.
    public var id: String { stratum }
}
