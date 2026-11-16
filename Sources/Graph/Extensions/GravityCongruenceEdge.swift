//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GravityCongruenceEdge.swift
//  Graph
//
//  One row of gstudio's gravity_congruence() `edges` table: an edge present
//  in both graphs, oriented from the earlier to the later population in the
//  first graph's node order, with each graph's asymmetry Δ along it.
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// An edge shared by two graphs, with the direction of gene flow along it in each.
public struct GravityCongruenceEdge: Sendable, Hashable {
    /// The edge's first population.
    public let from: String
    /// Its second population.
    public let to: String
    /// Its weight in the first graph.
    public let weight1: Double
    /// Its weight in the second graph.
    public let weight2: Double
    /// The asymmetry Δ from `from` to `to` in the first graph (positive: `from` is the source).
    public let delta1: Double
    /// The asymmetry in the second graph.
    public let delta2: Double

    /// Whether gene flow runs the same way in both graphs, or `nil` when Δ is within 10⁻¹² of zero in either.
    public var isConcordant: Bool? {
        let tiny = 1e-12
        guard abs(delta1) >= tiny, abs(delta2) >= tiny else { return nil }
        return (delta1 > 0) == (delta2 > 0)
    }
}
