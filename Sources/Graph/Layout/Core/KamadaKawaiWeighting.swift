//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  KamadaKawaiWeighting.swift
//  Graph
//
//  Created by Rodney Dyer on 2026.10.21.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// How edge weights become the graph-theoretic distances Kamada–Kawai tries to
/// reproduce as Euclidean distances.
public enum KamadaKawaiWeighting: Sendable, Equatable {
    /// Every edge has length 1, so distances are hop counts.
    case unweighted

    /// Edge weights are used as edge lengths as-is.
    case edgeWeights

    /// Edge weights plus `medianFraction × median(weight)`, which is what
    /// gstudio's `.layout_function("kk")` passes to `igraph::layout_with_kk()`.
    /// The floor stops near-zero genetic distances from collapsing nodes onto
    /// each other. `0.25` matches gstudio.
    case flooredEdgeWeights(medianFraction: Double = 0.25)
}
