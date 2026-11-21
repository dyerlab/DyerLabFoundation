//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Point3D.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2024.12.01.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import SwiftUI

/// A point in three-dimensional space using `CGFloat` components.
///
/// Used primarily for color-space arithmetic (mapping RGB to a 3D coordinate)
/// and for distance calculations in chart and visualization contexts.
public struct Point3D: Sendable, Equatable {

    let x: CGFloat
    let y: CGFloat
    let z: CGFloat

    /// Creates a point with explicit x, y, and z coordinates.
    ///
    /// - Parameters:
    ///   - x: The x-axis component.
    ///   - y: The y-axis component.
    ///   - z: The z-axis component.
    public init(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// Creates a point whose components are the red, green, and blue channels of a `Color`.
    ///
    /// - Parameter color: The color whose RGB components populate x, y, and z.
    public init(color: Color) {
        let components = color.components
        x = components.red
        y = components.green
        z = components.blue
    }

    /// Returns whether two points have identical x, y, and z components.
    ///
    /// - Parameters:
    ///   - lhs: The first point.
    ///   - rhs: The second point.
    /// - Returns: `true` if all three components are equal.
    public static func ==(lhs: Point3D, rhs: Point3D) -> Bool {
        lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z
    }

    /// Returns the squared Euclidean distance to another point.
    ///
    /// Prefer this over `distance(to:)` when only ordering is needed, since it avoids a square root.
    ///
    /// - Parameter p: The point to measure against.
    /// - Returns: The squared distance (dx² + dy² + dz²).
    public func squaredDistance(to p: Point3D) -> CGFloat {
        let dx = (self.x - p.x)
        let dy = (self.y - p.y)
        let dz = (self.z - p.z)
        return dx*dx + dy*dy + dz*dz
    }
}

public extension Point3D {

    /// The origin point (0, 0, 0).
    static let zero = Point3D(0, 0, 0)

    /// Adds two points component-wise.
    ///
    /// - Parameters:
    ///   - lhs: The first point.
    ///   - rhs: The second point.
    /// - Returns: The component-wise sum.
    static func +(lhs: Point3D, rhs: Point3D) -> Point3D {
        Point3D(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    /// Divides all components of a point by a scalar.
    ///
    /// - Parameters:
    ///   - lhs: The point.
    ///   - rhs: The divisor.
    /// - Returns: The point with each component divided by `rhs`.
    static func /(lhs: Point3D, rhs: CGFloat) -> Point3D {
        Point3D(lhs.x / rhs, lhs.y / rhs, lhs.z / rhs)
    }
}
