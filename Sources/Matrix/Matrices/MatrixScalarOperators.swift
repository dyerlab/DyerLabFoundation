//
//  MatrixScalarOperators.swift
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
//  Created by Rodney Dyer on 6/10/21.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.

import Accelerate


/// Scalar addition to matrix
/// - Parameters:
///  - X: The matrix
///  - s: The scalar (Double) to multiply it against
/// - Returns: The matrix after scalar addition
public func +( X: Matrix, s: Double ) -> Matrix {
    return Matrix( X.rows, X.cols, (X.values + s ) )
}

/// Scalar subtraction to matrix
/// - Parameters:
///  - X: The matrix
///  - s: The scalar (Double) to multiply it against
/// - Returns: The matrix after scalar subtraction
public func -( X: Matrix, s: Double ) -> Matrix {
    return Matrix( X.rows, X.cols, (X.values - s ) )
}

/// Scalar multiplication to matrix
/// - Parameters:
///  - X: The matrix
///  - s: The scalar (Double) to multiply it against
/// - Returns: The matrix after scalar multiplication
public func *( X: Matrix, s: Double ) -> Matrix {
    return Matrix( X.rows, X.cols, (X.values * s ) )
}

/// Scalar division to matrix
/// - Parameters:
///  - X: The matrix
///  - s: The scalar (Double) to multiply it against
/// - Returns: The matrix after scalar division
public func /( X: Matrix, s: Double ) -> Matrix {
    return Matrix( X.rows, X.cols, (X.values / s ) )
}
