//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DensityPoint.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// One point on a density curve.
public struct DensityPoint: Identifiable, Equatable, Sendable {
    /// The point's position on the x axis, which identifies it.
    public var id: Double { x }
    /// The value at which the density is estimated.
    public let x: Double
    /// The estimated density.
    public let density: Double

    /// Creates a point on a density curve.
    ///
    /// - Parameters:
    ///   - x: The value at which the density is estimated.
    ///   - density: The estimated density.
    public init(x: Double, density: Double) {
        self.x = x
        self.density = density
    }
}
