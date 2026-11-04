//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  CellGraph+LeastCost.swift
//  Matrix
//
//  Finding sites on the graph, and least-cost distances between them by
//  Dijkstra's algorithm (gdistance::costDistance). Least cost is also the
//  large-θ limit of the randomized-shortest-path distances.
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension CellGraph {

    /// The node of the cell containing a longitude and latitude.
    ///
    /// - Parameters:
    ///   - longitude: The longitude, in degrees.
    ///   - latitude: The latitude, in degrees.
    /// - Returns: The node, or `nil` if the point is outside the raster or in an impassable cell.
    public func node(longitude: Double, latitude: Double) -> Int? {
        guard let cell = resistance.cell(longitude: longitude, latitude: latitude) else { return nil }
        let node = nodeOfCell[cell.row * resistance.cols + cell.col]
        return node >= 0 ? Int(node) : nil
    }

    /// The least-cost distances between nodes.
    ///
    /// - Parameters:
    ///   - origins: The nodes to measure from.
    ///   - destinations: The nodes to measure to.
    /// - Returns: An `origins.count × destinations.count` matrix of path costs, `.infinity` between nodes in
    ///   different regions, or `nil` if a node is out of range.
    public func leastCostDistances(from origins: [Int], to destinations: [Int]) -> [[Double]]? {
        guard (origins + destinations).allSatisfy({ $0 >= 0 && $0 < nodeCount }) else { return nil }
        return origins.map { origin in
            let cost = leastCosts(from: origin)
            return destinations.map { cost[$0] }
        }
    }

    /// The least cost from one node to every node.
    func leastCosts(from origin: Int) -> [Double] {
        var cost = [Double](repeating: .infinity, count: nodeCount)
        var settled = [Bool](repeating: false, count: nodeCount)
        var queue = NodeHeap()
        cost[origin] = 0
        queue.push(node: origin, cost: 0)
        while let (node, reached) = queue.pop() {
            guard !settled[node] else { continue }
            settled[node] = true
            for step in steps(from: node) {
                let next = Int(targets[step])
                let candidate = reached + costs[step]
                if candidate < cost[next] {
                    cost[next] = candidate
                    queue.push(node: next, cost: candidate)
                }
            }
        }
        return cost
    }
}
