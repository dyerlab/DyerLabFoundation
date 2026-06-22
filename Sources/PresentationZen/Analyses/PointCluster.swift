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
//  PointCluster.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 12/1/24.
//

import Foundation
import CoreGraphics

public class PointCluster {
    
    var points: [Point3D] = []
    var center: Point3D
    
    public init( center: Point3D ) {
        self.center = center
    }
    
    public func estimateCenter() -> Point3D {
        if points.isEmpty {
            return Point3D.zero
        }
        return points.reduce( Point3D.zero, +) / CGFloat(points.count)
    }
    
    public func updateCenter() {
        if points.isEmpty { return }
        let currentCenter = self.estimateCenter()
        self.center = points.min(by: { $0.squaredDistance(to: currentCenter) < $1.squaredDistance(to: currentCenter)})!
    }
    
}




