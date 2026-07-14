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

/// A reference to a `Stratum` a node's individuals belong to at some
/// ancestor hierarchical level (e.g. a Family-level node tagged with its
/// Population and Region). Carries only enough to identify the stratum —
/// not its full roster of individuals — so a downstream app can regroup or
/// recolor a graph by any level without needing the original dataset.
public struct StratumReference: Sendable, Equatable, Hashable, Identifiable {

    /// The referenced stratum's identifier.
    public var id: UUID

    /// The hierarchical category this stratum belongs to (e.g. "Population", "Region").
    public var level: String

    /// The stratum's name at that level (e.g. "SBP", "North").
    public var name: String

    /// Initializes a new stratum reference.
    ///
    /// - Parameters:
    ///   - id: The referenced stratum's identifier (defaults to a new `UUID`).
    ///   - level: The hierarchical category this stratum belongs to (e.g. "Population", "Region").
    ///   - name: The stratum's name at that level (e.g. "SBP", "North").
    public init(id: UUID = UUID(), level: String, name: String) {
        self.id = id
        self.level = level
        self.name = name
    }
}
