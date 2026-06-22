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
//  VectorScalarOperators.swift
//  
//  Created by Rodney Dyer on 6/10/21.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.


import Accelerate


/// The Typealias as a function operator that takes a vector, stride, double, and pointer to vector result for vector/scalar operations
typealias OperatorVectorScalar = ((_: UnsafePointer<Double>, _: vDSP_Stride,
                                   _: UnsafePointer<Double>, _:
                                    UnsafeMutablePointer<Double>, _: vDSP_Stride,
                                   _: vDSP_Length) -> ())

/// Utilitiy function to run all the individual operators 'cuz I'm lazy and do not want to repeat the same code ell over the place.
func vectorScalarOperation(_ operation: OperatorVectorScalar, _ x: Vector, _ s: Double ) -> Vector {
    var ret = Vector(repeating: 0.0, count: x.count )
    var y = s
    operation( x, 1, &y, &ret, 1, vDSP_Length(x.count) )
    return ret
}





/// Scalar addition to vector
/// - Parameters:
///   - v: The `Vector`
///   - s: A `Double` scalar value
/// - Returns: The vector resulting from scalar addition
public func +(v: Vector, s: Double ) -> Vector {
    return vectorScalarOperation( vDSP_vsaddD, v, s)
}

/// Scalar subtraction to vector
/// - Parameters:
///   - v: The `Vector`
///   - s: A `Double` scalar value
/// - Returns: The vector resulting from scalar subtraction
public func -(v: Vector, s: Double ) -> Vector {
    return vectorScalarOperation( vDSP_vsaddD, v, -s)
}

/// Scalar muiltiplication to vector
/// - Parameters:
///   - v: The `Vector`
///   - s: A `Double` scalar value
/// - Returns: The vector resulting from scalar addition
public func *(v: Vector, s: Double ) -> Vector {
    return vectorScalarOperation( vDSP_vsmulD, v, s)
}

/// Scalar division to vector
/// - Parameters:
///   - v: The `Vector`
///   - s: A `Double` scalar value
/// - Returns: The vector resulting from scalar division
public func /(v: Vector, s: Double ) -> Vector {
    return vectorScalarOperation( vDSP_vsdivD, v, s)
}


