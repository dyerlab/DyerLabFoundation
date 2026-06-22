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
//  Vector.swift
//  Created by Rodney Dyer on 6/10/21.


import Foundation
import Accelerate
import SceneKit
import CoreGraphics

/// A vector of Double values with mathematical operations and statistical functions.
///
/// `Vector` is a type alias for `[Double]` extended with numerical and statistical operations.
/// Supports element-wise arithmetic, statistical computations, and integration with matrix operations.
/// Most operations leverage Apple's Accelerate framework for optimal performance on large datasets.
///
/// ## Creating Vectors
///
/// ```swift
/// let v1 = Vector([1.0, 2.0, 3.0, 4.0, 5.0])
/// let v2 = Vector(repeating: 0.0, count: 5)
/// let v3 = Vector.zeros(10)
/// let v4 = Vector.random(length: 100, type: .normal_0_1)
/// ```
///
/// ## Mathematical Operations
///
/// Supports element-wise operations with scalars and other vectors:
/// ```swift
/// let a = v1 + 2.0      // Add scalar
/// let b = v1 + v2       // Add vectors
/// let dot = v1 .* v2    // Dot product (scalar result)
/// let dist = distance(v1, v2)  // Euclidean distance
/// ```
///
/// ## Statistical Functions
///
/// ```swift
/// print(v1.mean)      // Arithmetic mean
/// print(v1.variance)  // Sample variance
/// print(v1.sd)        // Standard deviation
/// print(v1.minimum)   // Minimum value
/// print(v1.maximum)   // Maximum value
/// ```
public typealias Vector = [Double]



extension Vector {
    
    /// The sum of all elements in the vector.
    ///
    /// - Returns: The sum of all elements
    ///
    /// ## Example
    /// ```swift
    /// let v = Vector([1.0, 2.0, 3.0, 4.0, 5.0])
    /// print(v.sum)  // 15.0
    /// ```
    public var sum: Double {
        get {
            return self.reduce( 0.0, + )
        }
    }
    
    /// The arithmetic mean (average) of all elements.
    ///
    /// - Returns: The mean value, or `NaN` if the vector is empty
    ///
    /// ## Example
    /// ```swift
    /// let v = Vector([1.0, 2.0, 3.0, 4.0, 5.0])
    /// print(v.mean)  // 3.0
    /// ```
    public var mean: Double {
        guard !self.isEmpty else { return Double.nan }
        return self.reduce(0,+) / Double( self.count )
        
    }
    

    /// The sample variance of the vector.
    ///
    /// Uses (n-1) denominator (Bessel's correction) for an unbiased estimator.
    ///
    /// - Returns: The variance, or `NaN` if the vector is empty or has one element
    ///
    /// ## Example
    /// ```swift
    /// let v = Vector([1.0, 2.0, 3.0, 4.0, 5.0])
    /// print(v.variance)  // 2.5
    /// ```
    public var variance: Double {
        guard !self.isEmpty else { return Double.nan }
        let mean = self.mean
        let squaredDiffs = self.map { ($0 - mean) * ($0 - mean) }
        return squaredDiffs.reduce(0.0, +) / Double(self.count - 1)
    }
    
    /// The sample standard deviation of the vector.
    ///
    /// Computed as the square root of the sample variance.
    ///
    /// - Returns: The standard deviation, or `NaN` if the vector is empty or has one element
    ///
    /// ## Example
    /// ```swift
    /// let v = Vector([1.0, 2.0, 3.0, 4.0, 5.0])
    /// print(v.sd)  // sqrt(2.5) ≈ 1.58
    /// ```
    public var sd: Double {
        let v = self.variance
        if v.isNaN { return Double.nan }
        return sqrt( v )
    }
    
    
    /// The magnitude (L2 norm) of the vector.
    ///
    /// Computed as: `sqrt(x₁² + x₂² + ... + xₙ²)`
    ///
    /// - Returns: The Euclidean length of the vector
    ///
    /// ## Example
    /// ```swift
    /// let v = Vector([3.0, 4.0])
    /// print(v.magnitude)  // 5.0
    /// ```
    public var magnitude: Double {
        get {
            let v = self
            return  sqrt( (v * v).sum )
        }
    }
    
    /// The minimum value in the vector.
    ///
    /// - Returns: The smallest element, or `nil` if the vector is empty
    public var minimum: Double? {
        self.min()
    }

    /// The maximum value in the vector.
    ///
    /// - Returns: The largest element, or `nil` if the vector is empty
    public var maximum: Double? {
        self.max()
    }
    
    
    /// The first element (x-coordinate).
    ///
    /// Useful when treating the vector as a point in space.
    ///
    /// - Returns: The first element, or `0.0` if the vector is empty
    public var x: Double {
        return self.count > 0 ? self[0] : 0.0
    }

    /// The second element (y-coordinate).
    ///
    /// Useful when treating the vector as a point in space.
    ///
    /// - Returns: The second element, or `0.0` if the vector has fewer than 2 elements
    public var y: Double {
        return self.count > 1 ? self[1] : 0.0
    }

    /// The third element (z-coordinate).
    ///
    /// Useful when treating the vector as a point in 3D space.
    ///
    /// - Returns: The third element, or `0.0` if the vector has fewer than 3 elements
    public var z: Double {
        return self.count > 2 ? self[2] : 0.0
    }

    /// Returns a unit vector (normalized to magnitude 1).
    ///
    /// Each element is divided by the vector's magnitude.
    ///
    /// - Returns: A normalized copy of the vector
    ///
    /// ## Example
    /// ```swift
    /// let v = Vector([3.0, 4.0])
    /// let normalized = v.normal  // [0.6, 0.8]
    /// print(normalized.magnitude) // 1.0
    /// ```
    public var normal: Vector {
        return self/magnitude
    }
    
    
    /// Return random normalized vector
    public static func randomNormalizedVector( size: Int = 512) -> Vector {
        let raw = (0..<size).map { _ in Double.random(in: -1.0...1.0) }
        let magnitude = sqrt(raw.map { $0 * $0 }.reduce(0.0, +))
        return raw.map { $0 / magnitude }
    }
    
    /// Returns the coordinate as a CGPoint in 2-space
    public var asCGPoint: CGPoint {
        switch self.count {
        case 0:
            return CGPoint(x: 0, y: 0)
        case 1:
            return CGPoint(x: self[0], y:0)
        default:
            return CGPoint(x: self[0], y: self[1])
        }
    }
    
    /// Self as a SCNVector3
    public var asSNCVector3: SCNVector3 {
        switch self.count {
        case 0:
            return SCNVector3Make(0, 0, 0)
            
#if os(macOS)
        case 1:
            return SCNVector3Make(CGFloat(self[0]), 0.0, 0.0)
        case 2:
            return SCNVector3Make(CGFloat(self[0]), CGFloat(self[1]), 0)
        default:
            return SCNVector3Make(CGFloat(self[0]), CGFloat(self[1]), CGFloat(self[2]))
#elseif os(iOS)
        case 1:
            return SCNVector3Make(Float(self[0]), 0.0, 0.0)
        case 2:
            return SCNVector3Make(Float(self[0]), Float(self[1]), 0)
        default:
            return SCNVector3Make(Float(self[0]), Float(self[1]), Float(self[2]))
#endif
        }
    }
    
    public func smallest( other: Vector ) -> Vector {
        if self.count != other.count {
            return self
        }
        var ret = Vector.zeros( self.count )
        for i in 0 ..< self.count {
            ret[i] = Swift.min( self[i], other[i])
        }
        return ret
    }
    
    public func largest( other: Vector ) -> Vector {
        if self.count != other.count {
            return self
        }
        var ret = Vector.zeros( self.count )
        for i in 0 ..< self.count {
            ret[i] = Swift.max( self[i], other[i])
        }
        return ret
    }
    
    /// This function constrains each of the values in the vector to the designated range
    ///  - Parameters:
    ///   - minimum: The minimum value to constrain the value to.
    ///   - maximum: The maximum value to constrain the value to.
    public func constrain(minimum: Double, maximum: Double) -> Vector {
        var ret = Vector(repeating: 0.0, count: self.count)
        for i in 0..<self.count {
            if self[i] < minimum {
                ret[i] = minimum
            }
            else if self[i] > maximum {
                ret[i] = maximum
            } else {
                ret[i] = self[i]
            }
        }
        return ret
    }
    
    public func limitAnnealingMagnitude( temp: Double ) -> Vector {
        var ret = Vector.zeros( self.count )
        for i in 0..<count {
            if self[i] < 0 {
                ret[i] = -1.0 * Double.minimum( temp, abs(self[i]) )
            } else {
                ret[i] = Double.minimum( temp, self[i] )
            }
        }
        return ret
    }
    
    /// Create a zero vector
    ///
    /// - Parameters length: How long you want the vector
    /// - Returns A `Vector` of proper length with zeros
    public static func zeros(_ length: Int ) -> Vector  {
        return Vector( repeating: 0.0, count: length)
    }
    
    
    /// Creats a random vector values
    /// - Parameters:
    ///   - length: The length of the vector
    ///   - type: The type of data requested, 1 = uniform [0,1], 2 = uniform [-1,1], 3 = normal[0,1]
    /// - Returns: Vector of random values
    public static func random( length: Int, type: RangeEnum = .uniform_0_1 ) -> Vector {
        var seed = (0..<4).map { _ in
            Int32(Random.within(0.0...4095.0))
        }
        
        var dist = Int32( type.rawValue )
        var n = Int32( length )
        var ret = Vector(repeating: 0.0, count: length)
        
        dlarnv_(&dist, &seed, &n, &ret)
        
        return ret
    }
    
    
    public var studentized: Vector? {
        guard let minVal = self.minimum else { return nil }
        let ret = self - minVal
        guard let maxVal = ret.maximum,
              maxVal != 0 else { return nil }
        return ret.map { $0 / maxVal }
    }
    

    
    
}




// MARK: - Overriding rSourceConverible
extension Vector: rSourceConvertible {
    
    public func toR() -> String {
        var ret = "c("
        ret += self.map{ String("\($0)")}.joined(separator: ", ")
        ret += ")"
        return ret
    }
    
}








