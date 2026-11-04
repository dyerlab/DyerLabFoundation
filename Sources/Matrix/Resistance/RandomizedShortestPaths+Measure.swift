//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RandomizedShortestPaths+Measure.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension RandomizedShortestPaths {

    /// Which distance to report between two sites.
    ///
    /// All three fall to the least-cost distance as θ grows. As θ → 0 the free energy and the expected cost
    /// both rise to the cost the reference random walk expects to pay before it reaches the destination.
    public enum Measure: Sendable, Hashable, Codable {
        /// The free-energy distance, −log(z_ij) / θ (Kivimäki et al. 2014): the expected cost plus the
        /// walk's divergence from the reference walk, divided by θ. It needs one solve per destination,
        /// so it's the cheapest of the three. Undefined at θ = 0.
        case freeEnergy
        /// The expected cost of all the steps taken on the way, gdistance `rSPDistance(totalNet = "total")`.
        case expectedCost
        /// The expected cost of the net flow along each step (flow there minus flow back, where positive),
        /// gdistance `rSPDistance(totalNet = "net")`, its default. Back-and-forth wandering cancels, so it's
        /// smaller than ``expectedCost``.
        case netExpectedCost
    }
}
