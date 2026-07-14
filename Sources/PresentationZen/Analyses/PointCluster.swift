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

/// A mutable cluster of `Point3D`s, used as k-means' per-iteration accumulator
/// in `kMeansClustering(points:k:)`.
public class PointCluster {

    var points: [Point3D] = []
    var center: Point3D

    /// Creates an empty cluster centered at `center`.
    ///
    /// - Parameter center: The cluster's initial center.
    public init( center: Point3D ) {
        self.center = center
    }

    /// Computes the centroid (mean) of `points`.
    ///
    /// - Returns: The mean of `points`, or `Point3D.zero` if the cluster is empty.
    public func estimateCenter() -> Point3D {
        if points.isEmpty {
            return Point3D.zero
        }
        return points.reduce( Point3D.zero, +) / CGFloat(points.count)
    }

    /// Snaps `center` to whichever member of `points` is closest to the current centroid.
    ///
    /// Unlike `estimateCenter()`, the result is always an actual member point rather than
    /// their mean — a no-op when `points` is empty.
    public func updateCenter() {
        if points.isEmpty { return }
        let currentCenter = self.estimateCenter()
        self.center = points.min(by: { $0.squaredDistance(to: currentCenter) < $1.squaredDistance(to: currentCenter)})!
    }

}




