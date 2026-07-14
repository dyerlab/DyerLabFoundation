//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  ConvexHull.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 8/23/21.
//

import Foundation
import CoreLocation
import MapKit

/// Computes the convex hull of a set of geographic coordinates using a gift-wrapping algorithm.
///
/// The hull is expressed as an ordered `[CLLocationCoordinate2D]` and exposed as an
/// `MKPolygon` for direct use with MapKit overlays.  At least three non-collinear points
/// are required; fewer than three points leave `convexHull` empty.
public class ConvexHull {

    /// Unique identifier for this hull instance.
    public var id = UUID()

    /// The computed hull vertices in counter-clockwise order.
    public var convexHull = [CLLocationCoordinate2D]()

    /// The hull expressed as an `MKPolygon` overlay.
    public var polygon: MKPolygon {
        return MKPolygon(coordinates: convexHull, count: convexHull.count)
    }

    /// The turn direction of three consecutive hull points.
    public enum ClockwiseOrientation {
        /// Points are collinear (no turn).
        case colinear
        /// Points make a clockwise turn.
        case clockwise
        /// Points make a counter-clockwise turn.
        case counterclockwise
    }

    /// Creates a convex hull from a set of geographic coordinates.
    ///
    /// - Parameter pts: The input coordinates. At least three non-collinear points
    ///   are required; otherwise `convexHull` remains empty.
    public init( pts: [CLLocationCoordinate2D]) {
        findHull(points: pts )
    }

    private func leftmostIndex( coords: [CLLocationCoordinate2D] ) -> Int {
        var mnIdx = 0
        for i in 1 ..< coords.count {
            if coords[i].longitude < coords[mnIdx].longitude {
                mnIdx = i
            } else if coords[i].longitude == coords[mnIdx].longitude {
                if coords[i].latitude > coords[mnIdx].latitude {
                    mnIdx = i
                }
            }
        }
        return mnIdx
    }

    private func distanceSquared(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let dx = a.longitude - b.longitude
        let dy = a.latitude - b.latitude
        return dx * dx + dy * dy
    }


    private func orientation(p: CLLocationCoordinate2D, q: CLLocationCoordinate2D, r: CLLocationCoordinate2D) -> ClockwiseOrientation {
        let val = (q.latitude - p.latitude) * (r.longitude - q.longitude) - (q.longitude - p.longitude) * (r.latitude - q.latitude)
        let epsilon = 1e-10
        if abs(val) < epsilon {
            return .colinear
        } else if val > 0 {
            return .clockwise
        } else {
            return .counterclockwise
        }
    }


    private func findHull(points: [CLLocationCoordinate2D]) {
        let n = points.count
        guard n >= 3 else {
            print("Warning: You must have at least 3 points to make a convex hull")
            return
        }

        let leftIdx = leftmostIndex(coords: points)
        var hull = [CLLocationCoordinate2D]()

        var p = leftIdx
        var iterations = 0
        repeat {
            hull.append(points[p])
            var q = (p + 1) % n
            for i in 0..<n {
                if i == p { continue }

                let o = orientation(p: points[p], q: points[q], r: points[i])

                if o == .counterclockwise {
                    q = i
                } else if o == .colinear {
                    // Choose the farther point from p
                    let d1 = distanceSquared(points[p], points[q])
                    let d2 = distanceSquared(points[p], points[i])
                    if d2 > d1 {
                        q = i
                    }
                }
            }
            p = q
            iterations += 1
            if iterations > n * 2 {
                print("Hull computation did not converge, breaking loop after \(iterations) iterations.")
                break
            }
        } while p != leftIdx

        self.convexHull = hull
    }

}



extension ConvexHull: Hashable, Equatable {

    /// Two hulls are equal when they share the same `id`.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand hull.
    ///   - rhs: The right-hand hull.
    /// - Returns: `true` if both hulls have the same UUID.
    public static func == (lhs: ConvexHull, rhs: ConvexHull) -> Bool {
        return lhs.id == rhs.id
    }

    /// Hashes the hull's `id` into the supplied hasher.
    ///
    /// - Parameter hasher: The hasher to feed.
    public func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }

}


extension ConvexHull: CustomStringConvertible {
    /// A human-readable listing of the hull vertices.
    public var description: String {
        var ret = "ConvexHull(\(id)): \n"
        self.convexHull.forEach {
            ret += "-> (\($0.latitude),  \($0.longitude)) \n"
        }
        ret += "____î"
        return ret
    }
}
