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
//  DataColumnRole.swift
//
//  The role a column plays in a plot. A `DataTable` maps roles to column
//  names; charts read columns by role rather than by position, so the same
//  table can be re-bound to different encodings without copying data.
//

import Foundation

/// The plotting role assigned to a column of a ``DataTable``.
///
/// The legacy `category` and `grouping` fields collapse into roles here: a
/// categorical x-axis is simply the ``x`` role bound to a `String` column,
/// and color grouping is the ``series`` role.
public enum DataColumnRole: String, Hashable, Sendable, CaseIterable {
    /// The positional x encoding (quantitative, temporal, or categorical).
    case x
    /// The positional y encoding (always quantitative).
    case y
    /// The color/series encoding used to split a chart into groups.
    case series
    /// A per-point text annotation.
    case label
}

/// The underlying value kind of a ``DataTable`` column.
public enum ColumnKind: Sendable {
    case number
    case date
    case category
}
