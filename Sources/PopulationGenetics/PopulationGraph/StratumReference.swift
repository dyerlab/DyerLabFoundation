//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StratumReference.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.07.14.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

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
