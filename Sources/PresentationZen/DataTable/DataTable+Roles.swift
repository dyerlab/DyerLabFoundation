//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  DataTable+Roles.swift
//
//  Fluent, immutable role assignment. Each call returns a copy of the table
//  with one role rebound; the backing `DataFrame` is copy-on-write so the
//  copies are cheap.
//

import Foundation

public extension DataTable {

    /// Returns a copy with `column` bound to the given role.
    func role(_ role: DataColumnRole, _ column: String) -> DataTable {
        var copy = self
        copy.setRole(role, column)
        return copy
    }

    /// Returns a copy with `column` bound to the ``DataColumnRole/x`` role.
    func x(_ column: String) -> DataTable { role(.x, column) }

    /// Returns a copy with `column` bound to the ``DataColumnRole/y`` role.
    func y(_ column: String) -> DataTable { role(.y, column) }

    /// Returns a copy with `column` bound to the ``DataColumnRole/series`` role.
    func series(_ column: String) -> DataTable { role(.series, column) }

    /// Returns a copy with `column` bound to the ``DataColumnRole/label`` role.
    func label(_ column: String) -> DataTable { role(.label, column) }

    /// The column name bound to a role, if any.
    func column(for role: DataColumnRole) -> String? { roles[role] }
}

extension DataTable {

    /// Mutating role assignment used by the fluent wrappers.
    mutating func setRole(_ role: DataColumnRole, _ column: String) {
        roles[role] = column
    }
}
