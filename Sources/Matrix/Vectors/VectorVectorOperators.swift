//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  VectorVectorOperators.swift
//
//  Created by Rodney Dyer on 6/10/21.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Accelerate

/// Define a typealias for a function operator that takes arguments that work in lapac functions for vector/vector operations
typealias OperatorVectorVector = ((_: UnsafePointer<Double>, _: vDSP_Stride,
                                   _: UnsafePointer<Double>, _: vDSP_Stride,
                                   _: UnsafeMutablePointer<Double>, _: vDSP_Stride,
                                   _: vDSP_Length) -> ())


/// Generic function for performing Vector/Vector Operations
///
/// This is a convience function to make it easier to write all the operation code that follows.
/// - Parameters:
///   - operation: The LAPAC function to call
///   - x: The left `Vector`
///   - y: The right `Vector`
/// - Returns: The result of the `operaiton` function on the two vectors.
func vectorVectorOperation(_ operation: OperatorVectorVector, _ x: Vector, _ y: Vector ) -> Vector {
    var z = Vector(repeating: 0.0, count: x.count)
    operation(x, 1, y, 1, &z, 1, vDSP_Length(x.count))
    return z
}

/// Equality Operator
/// - Parameters:
///   - lhs: The left vector
///   - rhs: The right vector
/// - Returns: A boolean indicating the elementwise equality of the values in each.
public func ==(lhs: Vector, rhs: Vector ) -> Bool {
    guard lhs.count == rhs.count else { return false }
    return zip(lhs, rhs).allSatisfy { (l, r) in
        fabs( l.distance(to: r)) <= Double.leastNormalMagnitude
    }
}


/// Elementwise Addition Operator
/// - Parameters:
///   - lhs: The left vector
///   - rhs: The right vector
/// - Returns: The `Vector` resulting from the addition of both vectors.
public func +(lhs: Vector, rhs: Vector ) -> Vector {
    return vectorVectorOperation( vDSP_vaddD, lhs, rhs )
}

/// Elementwise Subtraction Operator
/// - Parameters:
///   - lhs: The left vector
///   - rhs: The right vector
/// - Returns: The `Vector` resulting from the subtraction of both vectors.
public func -(lhs: Vector, rhs: Vector ) -> Vector {
    return vectorVectorOperation( vDSP_vsubD, rhs, lhs )
}

/// Elementwise Multiplication Operator
/// - Parameters:
///   - lhs: The left vector
///   - rhs: The right vector
/// - Returns: The `Vector` resulting from the multiplication of both vectors.
public func *(lhs: Vector, rhs: Vector ) -> Vector {
    return vectorVectorOperation( vDSP_vmulD, lhs, rhs )
}

/// Elementwise Division Operator
/// - Parameters:
///   - lhs: The left vector
///   - rhs: The right vector
/// - Returns: The `Vector` resulting from the division of both vectors.
public func /(lhs: Vector, rhs: Vector ) -> Vector {
    return vectorVectorOperation( vDSP_vdivD, rhs, lhs )
}




/// The Dot Product of two vectors.
///
/// The dot product is the element-wise mutlication and the sum of the two passed vectors.
/// - Parameters:
///   - lhs: The left vector
///   - rhs: The right vector
/// - Returns: The sum of the element-wise multiplciation of the two vectors.
public func .*(lhs: Vector, rhs: Vector) -> Double {
    var ret: Double = 0.0
    vDSP_dotprD( lhs, 1, rhs, 1, &ret, vDSP_Length(lhs.count) )
    return ret
}

/// Estimates distance between two vectors
/// - Parameters:
///   - vec1: The first vector
///   - vec2: The second vector
/// - Returns: The distance between them
public func euclideanDistance(_ vec1: Vector, _ vec2: Vector) -> Double {
    var diff = [Double](repeating: 0.0, count: vec1.count)
    vDSP_vsubD(vec2, 1, vec1, 1, &diff, 1, vDSP_Length(vec1.count))

    var sumsq: Double = 0
    vDSP_svesqD(diff, 1, &sumsq, vDSP_Length(vec1.count))
    return sqrt(sumsq)
}

/// Estimates squared distance between two vectors
/// - Parameters:
///   - vec1: The first vector
///   - vec2: The second vector
/// - Returns: The distance between them
public func squaredEuclideanDistance(_ vec1: Vector, _ vec2: Vector) -> Double {
    var diff = [Double](repeating: 0.0, count: vec1.count)
    vDSP_vsubD(vec2, 1, vec1, 1, &diff, 1, vDSP_Length(vec1.count))

    var sumsq: Double = 0
    vDSP_svesqD(diff, 1, &sumsq, vDSP_Length(vec1.count))
    return sumsq
}





/// Estimates distance between two vectors
/// - Parameters:
///   - vec1: The first vector
///   - vec2: The second vector
/// - Returns: The distance between them
public func amovaDistance(_ vec1: Vector, _ vec2: Vector ) -> Double {
    return ((vec1 - vec2).map { $0 * $0 }).sum / 2.0 
}

