//
//  MatrixMatrixOperations.swift
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
//

import Foundation
import Accelerate


/// Matrix element-wise addition
/// - Parameters:
///  - lhs: The left matrix
///  - rhs: The right matrix
/// - Returns: A matrix resulting from element-wise addition, or an empty 0×0 matrix if dimensions differ.
public func +(lhs: Matrix, rhs: Matrix) -> Matrix {
    guard lhs.rows == rhs.rows && lhs.cols == rhs.cols else { return Matrix(0, 0) }
    return Matrix( lhs.rows, lhs.cols, lhs.values + rhs.values )
}

/// Matrix element-wise subtraction
/// - Parameters:
///  - lhs: The left matrix
///  - rhs: The right matrix
/// - Returns: A matrix resulting from element-wise subtraction, or an empty 0×0 matrix if dimensions differ.
public func -(lhs: Matrix, rhs: Matrix) -> Matrix {
    guard lhs.rows == rhs.rows && lhs.cols == rhs.cols else { return Matrix(0, 0) }
    return Matrix( lhs.rows, lhs.cols, lhs.values - rhs.values )
}


/// Matrix element-wise multiplication
/// - Parameters:
///  - lhs: The left matrix
///  - rhs: The right matrix
/// - Returns: A matrix resulting from element-wise multiplication, or an empty 0×0 matrix if dimensions differ.
public func *(lhs: Matrix, rhs: Matrix) -> Matrix {
    guard lhs.rows == rhs.rows && lhs.cols == rhs.cols else { return Matrix(0, 0) }
    return Matrix( lhs.rows, lhs.cols, lhs.values * rhs.values )
}


/// Matrix element-wise division
/// - Parameters:
///  - lhs: The left matrix
///  - rhs: The right matrix
/// - Returns: A matrix resulting from element-wise division, or an empty 0×0 matrix if dimensions differ.
public func /(lhs: Matrix, rhs: Matrix) -> Matrix {
    guard lhs.rows == rhs.rows && lhs.cols == rhs.cols else { return Matrix(0, 0) }
    return Matrix( lhs.rows, lhs.cols, lhs.values / rhs.values )
}


/// Matrix multiplication
///
/// This is the more complicated matrix multiplication requiring that the columns of the left matrix equal the rows of the right matrix
///   and the result is the saize of the rows of the left and the columns of the right.
/// - Parameters:
///  - lhs: The left matrix
///  - rhs: The right matrix
/// - Returns: A matrix resulting from matrix multiplication
public func .*(lhs: Matrix, rhs: Matrix ) -> Matrix {
    let ret = Matrix(lhs.rows, rhs.cols )
    vDSP_mmulD( lhs.values, 1,
                rhs.values, 1,
                &ret.values, 1,
                vDSP_Length(lhs.rows),
                vDSP_Length(rhs.cols),
                vDSP_Length(lhs.cols))
    return ret
}
