//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  SpatialMatrix.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

import CoreLocation
import Matrix
import PresentationZen

/// Marks a `DistanceMatrix` as holding pairwise great-circle distances. See
/// `pairwiseGreatCircleDistance`.
public enum GreatCircleKind: PairwiseMeasure {
    public static let columnName = "GreatCircleDistance"
}

/// A symmetric matrix of pairwise great-circle distances (km) among named locations.
public typealias SpatialMatrix = DistanceMatrix<GreatCircleKind>

/// Pairwise great-circle distance between every pair of named locations —
/// typically stratum centroids. Reuses `DistanceBetween`, the same haversine
/// primitive `[Node].PhysicalDistance` already uses for individual-level maps.
///
/// - Parameter locations: One coordinate per named group; groups without a
///   known location are simply omitted from the input.
/// - Returns: A `SpatialMatrix` over `locations`' keys, naturally sorted —
///   the same group-ordering convention `pairwisePhiST` uses, so the two can
///   be joined directly via `DataTable(pairwise:)`.
public func pairwiseGreatCircleDistance(locations: [String: CLLocationCoordinate2D]) -> SpatialMatrix {
    let groupNames = locations.keys.naturalSorted()
    var result = SpatialMatrix(groupNames: groupNames)
    for i in 0..<groupNames.count {
        for j in (i + 1)..<groupNames.count {
            result[i, j] = DistanceBetween(locations[groupNames[i]]!, locations[groupNames[j]]!)
        }
    }
    return result
}
