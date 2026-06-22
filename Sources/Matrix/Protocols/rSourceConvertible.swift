//  rSourceConvertible.swift
//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//
//  Created by Rodney Dyer on 1/10/22.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.

import Foundation

/// A protocol for types that can be converted to R source code.
///
/// Conforming types can export themselves as R-compatible code strings,
/// enabling easy data transfer between Swift and R for statistical analysis.
///
/// ## Conforming Types
/// - `Vector`: Exports as R vector `c(...)`
/// - `Matrix`: Exports as R matrix or tibble depending on row/column names
///
/// ## Example
/// ```swift
/// let v = Vector([1.0, 2.0, 3.0])
/// print(v.toR())  // "c(1.0, 2.0, 3.0)"
///
/// let M = Matrix(2, 2, [1.0, 2.0, 3.0, 4.0])
/// M.rowNames = ["A", "B"]
/// M.colNames = ["X", "Y"]
/// print(M.toR())  // Exports as tibble with row names
/// ```
public protocol rSourceConvertible {

    /// Converts the instance to R source code.
    ///
    /// - Returns: A string containing valid R code that recreates this object
    func toR() -> String

}
