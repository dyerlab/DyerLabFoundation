//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ParentageDesign.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.06.28.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// A collection of maternal families — the parentage sampling design.
public struct ParentageDesign: Sendable {

    /// The families in this design.
    public var families: [MaternalFamily]

    /// Creates a parentage design from a collection of maternal families.
    ///
    /// - Parameter families: The maternal families comprising this design.
    public init(families: [MaternalFamily]) {
        self.families = families
    }

    /// Ordinals of all mothers (adults) across families.
    public var adultOrdinals: [Int] { families.compactMap(\.mother) }

    /// Ordinals of all offspring across families.
    public var offspringOrdinals: [Int] { families.flatMap(\.offspring) }

    /// Returns the family with the given label, or `nil`.
    ///
    /// - Parameter id: The family label.
    /// - Returns: The family, or `nil`.
    public func family(id: String) -> MaternalFamily? {
        families.first { $0.id == id }
    }
}
