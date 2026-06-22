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
//  Random.swift
//  DLabMatrix
//
//  Created by Rodney Dyer on 6/15/21.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Utilities for generating random floating-point numbers.
///
/// Provides static methods for generating uniformly distributed random values
/// within specified ranges.
///
/// ## Example
/// ```swift
/// let value = Random.within(0.0...1.0)
/// let temperature = Random.within(-10.0...35.0)
/// ```
public struct Random {

    /// Generates a random floating-point value within a specified range.
    ///
    /// Uses uniform distribution to generate values between the lower and upper bounds (inclusive).
    ///
    /// - Parameter range: A closed range defining the minimum and maximum values
    /// - Returns: A random value of type `T` within the specified range
    ///
    /// ## Example
    /// ```swift
    /// let probability = Random.within(0.0...1.0)
    /// let coordinate = Random.within(-180.0...180.0)
    /// ```
    public static func within<T>(_ range: ClosedRange<T>) -> T where T: FloatingPoint, T: ExpressibleByFloatLiteral {
        return (range.upperBound - range.lowerBound) * (T(arc4random()) / T(UInt32.max)) + range.lowerBound
    }

}
