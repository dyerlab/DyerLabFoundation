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
//  kMeansClustering.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 12/1/24.
//

import Foundation

func findClosest(for p : Point3D, from clusters: [PointCluster]) -> PointCluster {
    return clusters.min(by: {$0.center.squaredDistance(to: p) < $1.center.squaredDistance(to: p)})!
}

func kMeansClustering( points: [Point3D], k: Int ) -> [PointCluster] {
    
    // Set up initial cluters
    var clusters = [PointCluster]()
    
    for _ in 0 ..< k {
        var p = points.randomElement()
        while p == nil || clusters.contains(where: {$0.center == p}) {
            p = points.randomElement()
        }
        clusters.append(PointCluster(center: p!))
    }
    
    // Assign points to closest cluster
    for p in points {
        let closest = findClosest(for: p, from: clusters)
        closest.points.append( p )
    }
    
    clusters.forEach{ $0.updateCenter() }
    
    // Iterate
    for _ in 0 ..< 10 {
        
        // reassign points
        clusters.forEach {
            $0.points.removeAll()
        }
        
        for p in points {
            let closest = findClosest(for: p, from: clusters)
            closest.points.append(p)
        }
        
        // Determine convergence
        var converged = true
        
        clusters.forEach {
            let oldCenter = $0.center
            $0.updateCenter()
            if oldCenter.squaredDistance(to: $0.center) > 0.001 {
                converged = false
            }
        }
        if converged {
            //print("Converged. Took \(i) iterations")
            break;
        }
    }
    
    // Return
    return clusters.sorted(by: {$0.points.count > $1.points.count } )
}
