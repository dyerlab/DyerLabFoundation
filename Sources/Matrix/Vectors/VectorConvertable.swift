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
//  VectorConvertible.swift
//
//  Created by Rodney Dyer on 6/10/21.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.



import Foundation

/// A protocol for types that can be converted to a `Vector`.
///
/// Conforming types can represent themselves as 1D vector structures,
/// enabling integration with vector operations and statistical functions.
///
/// ## Conforming Types
/// Implement the `asVector()` method to define how your type should be
/// represented as a vector.
///
/// ## Example
/// ```swift
/// struct Point3D: VectorConvertible {
///     var x, y, z: Double
///
///     func asVector() -> Vector {
///         return Vector([x, y, z])
///     }
/// }
/// ```
public protocol VectorConvertible {

    /// Converts the instance to a `Vector`.
    ///
    /// - Returns: A `Vector` representation of this object
    func asVector() -> Vector

}
