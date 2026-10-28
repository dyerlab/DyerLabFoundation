//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ColumnKind.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.06.23.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The underlying value kind of a ``DataTable`` column.
public enum ColumnKind: Sendable {
    /// A numeric column (`Double`, `Int` or `Float`).
    case number
    /// A `Date` column.
    case date
    /// A `String` column.
    case category
}
