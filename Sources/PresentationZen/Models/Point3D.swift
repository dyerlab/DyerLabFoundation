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
//  DataPoint3D.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 12/1/24.
//

import Foundation
import SwiftUI

public struct Point3D: Equatable {
    
    let x: CGFloat
    let y: CGFloat
    let z: CGFloat
    
    public init(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    public init( color: Color ) {
        let components = color.components
        x = components.red
        y = components.green
        z = components.blue
    }
    
    public static func ==(lhs: Point3D, rhs: Point3D) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z
    }
    
    public func squaredDistance(to p: Point3D) -> CGFloat {
        let dx = (self.x - p.x)
        let dy = (self.y - p.y)
        let dz = (self.z - p.z)
        return  dx*dx + dy*dy + dz*dz
    }
}



public extension Point3D {
    
    nonisolated(unsafe) static let zero = Point3D(0, 0, 0)
    
    static func +(lhs : Point3D, rhs : Point3D) -> Point3D {
        return Point3D(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }
    
    static func /(lhs : Point3D, rhs : CGFloat) -> Point3D {
        return Point3D(lhs.x / rhs, lhs.y / rhs, lhs.z / rhs)
    }
}

