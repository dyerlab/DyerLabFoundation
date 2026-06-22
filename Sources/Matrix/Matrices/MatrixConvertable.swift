//
//  MatrixConvertable.swift
//  DyerLabKit
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
//  Created by Rodney Dyer on 11/23/20.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation


/// A protocol for types that can be converted to a `Matrix`.
///
/// Conforming types can represent themselves as 2D matrix structures,
/// enabling integration with matrix algebra operations.
///
/// ## Conforming Types
/// Implement the `asMatrix()` method to define how your type should be
/// represented as a matrix.
///
/// ## Example
/// ```swift
/// struct DataSet: MatrixConvertible {
///     var rows: [[Double]]
///
///     func asMatrix() -> Matrix {
///         let flattened = rows.flatMap { $0 }
///         return Matrix(rows.count, rows[0].count, Vector(flattened))
///     }
/// }
/// ```
public protocol MatrixConvertible {

    /// Converts the instance to a `Matrix`.
    ///
    /// - Returns: A `Matrix` representation of this object
    func asMatrix() -> Matrix

}
