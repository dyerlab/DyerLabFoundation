//
//  Operators.swift
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


/// Defines new operator for Matrix Multiplication.
infix operator .* : MultiplicationPrecedence



/**
 Matrix, vector multiplication
 
 This function requires that the number of rows in `lhs` be equal to the length of `v`.
 - Parameters:
    - lhs: A matrix
    - v: A vector
 - Returns: a `Vector` of length equal to `v`.
 */
public func .* (lhs: Matrix, v: Vector) -> Vector {

    var ret = Vector.zeros( lhs.rows )
    
    // return empty vector
    if lhs.rows != v.count { return ret }
    
    
    for r in 0 ..< lhs.rows {
        let w = lhs.getRow(r: r)
        ret[r] = w .* v
    }

    return ret
}
