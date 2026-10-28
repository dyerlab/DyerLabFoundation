//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DataTable+Roles.swift
//  PresentationZen
//
//  Fluent, immutable role assignment. Each call returns a copy of the table
//  with one role rebound; the backing `DataFrame` is copy-on-write so the
//  copies are cheap.
//
//  Created by Rodney Dyer on 2026.06.23.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

public extension DataTable {

    /// Returns a copy with `column` bound to the given role.
    ///
    /// - Parameters:
    ///   - role: The role to bind.
    ///   - column: The column to bind it to.
    /// - Returns: A copy of the table with the role bound.
    func role(_ role: DataColumnRole, _ column: String) -> DataTable {
        var copy = self
        copy.setRole(role, column)
        return copy
    }

    /// Returns a copy with `column` bound to the ``DataColumnRole/x`` role.
    ///
    /// - Parameter column: The column to bind.
    /// - Returns: A copy of the table with the role bound.
    func x(_ column: String) -> DataTable { role(.x, column) }

    /// Returns a copy with `column` bound to the ``DataColumnRole/y`` role.
    ///
    /// - Parameter column: The column to bind.
    /// - Returns: A copy of the table with the role bound.
    func y(_ column: String) -> DataTable { role(.y, column) }

    /// Returns a copy with `column` bound to the ``DataColumnRole/series`` role.
    ///
    /// - Parameter column: The column to bind.
    /// - Returns: A copy of the table with the role bound.
    func series(_ column: String) -> DataTable { role(.series, column) }

    /// Returns a copy with `column` bound to the ``DataColumnRole/label`` role.
    ///
    /// - Parameter column: The column to bind.
    /// - Returns: A copy of the table with the role bound.
    func label(_ column: String) -> DataTable { role(.label, column) }

    /// The column name bound to a role, if any.
    ///
    /// - Parameter role: The role to look up.
    /// - Returns: The bound column's name, or `nil` if the role is unbound.
    func column(for role: DataColumnRole) -> String? { roles[role] }
}

extension DataTable {

    /// Mutating role assignment used by the fluent wrappers.
    ///
    /// - Parameters:
    ///   - role: The role to bind.
    ///   - column: The column to bind it to.
    mutating func setRole(_ role: DataColumnRole, _ column: String) {
        roles[role] = column
    }
}
