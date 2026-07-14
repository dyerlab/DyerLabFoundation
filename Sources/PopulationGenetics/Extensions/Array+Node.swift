//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Array+Node.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 6/20/25.
//
import Foundation
import Graph
import Matrix
import PresentationZen


/// Extensions for arrays of `Node` objects to compute spatial distance matrices.
public extension Array where Element == Node {

    /// Computes a pairwise physical distance matrix between all nodes.
    ///
    /// This property calculates geographic distances using the haversine formula
    /// for nodes with valid coordinates. Distances are measured in the same units
    /// returned by the `DistanceBetween` function (typically kilometers or meters).
    ///
    /// Nodes without coordinates receive a distance of infinity.
    ///
    /// - Returns: A symmetric `Matrix` of size N×N where `matrix[i,j]` is the distance between nodes i and j.
    var PhysicalDistance: Matrix {
        let N = self.count
        let ret = Matrix(N,N, .infinity)

        for i in 0 ..< N {
            if let coord1 = self[i].coordinate {
                for j in i ..< N {
                    if let coord2 = self[j].coordinate {
                        let dist = DistanceBetween( coord1, coord2 )
                        ret[i,j] = dist
                        ret[j,i] = dist
                    }
                }
            }
        }
        return ret
    }

}
