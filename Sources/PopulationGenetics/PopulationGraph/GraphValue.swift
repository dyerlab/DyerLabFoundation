//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GraphValue.swift
//  PopulationGenetics
//
//  Sparse, open-ended numeric data attached to a node or edge (elevation,
//  soil moisture, betweenness, bootstrap support, ...). Shares one shape so
//  the persistence layer can use a single codec for both `node_values` and
//  `edge_values`.
//
//  Created by Rodney Dyer on 2026.07.14.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// A single named numeric measurement attached to a node or edge.
public struct GraphValue: Sendable, Equatable, Hashable {

    /// Distinguishes data present when the node/edge was constructed
    /// (e.g. a sampled covariate) from data derived from the graph afterward
    /// (e.g. betweenness centrality).
    public enum Kind: String, Sendable, Codable {
        /// Data present when the node/edge was constructed (e.g. a sampled covariate).
        case intrinsic
        /// Data derived from the graph afterward (e.g. betweenness centrality).
        case extrinsic
    }

    /// The measurement's name (e.g. "elevation", "betweenness"). Freeform.
    public var name: String

    /// The measurement's value.
    public var value: Double

    /// Whether this value was present at construction time or derived later.
    public var kind: Kind

    /// Initializes a new named numeric measurement.
    ///
    /// - Parameters:
    ///   - name: The measurement's name (e.g. "elevation", "betweenness").
    ///   - value: The measurement's value.
    ///   - kind: Whether this value was present at construction time or derived later.
    public init(name: String, value: Double, kind: Kind) {
        self.name = name
        self.value = value
        self.kind = kind
    }
}
