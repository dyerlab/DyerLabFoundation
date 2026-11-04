//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RandomizedShortestPaths.swift
//  Matrix
//
//  Randomized-shortest-path (RSP) distances over a resistance cell graph
//  (Saerens et al. 2009; Kivimäki et al. 2014), following gdistance's
//  rSPDistance(). With P the reference walk and C the step costs,
//
//      W = P ∘ exp(−θ C)
//
//  and for each destination t the walk is absorbed at t: W's row t is zeroed
//  before solving with I − W. That keeps I − W well conditioned however small
//  θ is (without it, W → P, which is row-stochastic, and I − P is singular).
//  Then z = (I − W)⁻¹ e_t, the column of Z towards t, gives the free energy
//  −log(z_i) / θ, and with each origin's row of Z, zᵢᵀ = e_iᵀ (I − W)⁻¹, the
//  expected number of passages along each step,
//
//      N_kl = zᵢ[k] W_kl z[l] / z[i],
//
//  whose cost-weighted sum is the expected cost (gdistance's "total"), or
//  with N − Nᵀ kept where positive, the net expected cost ("net").
//
//  Only the region holding t is solved, since a walk can never reach t from
//  anywhere else, and a region without the absorbing cell makes I − W nearly
//  singular at small θ.
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Randomized-shortest-path distances between sites on a resistance surface.
///
/// θ sets how far the walkers stray from the cheapest route. Near 0 they wander like the reference random
/// walk, and distances behave like random-walk (circuit) distances. As θ grows they concentrate on the
/// least-cost path. θ is in reciprocal cost units: with costs in resistance × metres, θ·(a typical
/// least-cost distance) is what matters, so θ = 10 / 5,000 m is fairly concentrated for sites 5 km apart.
///
/// ```swift
/// let rsp = RandomizedShortestPaths(graph: graph, theta: 1e-3)!
/// let d = rsp.distances(from: sites, to: sites, measure: .freeEnergy)!
/// ```
///
/// Results match gdistance's `rSPDistance()` for ``CellGraph/ReferenceWalk/conductance`` graphs. The
/// ``CellGraph/ReferenceWalk/areaCorrected`` walk, the default on longitude/latitude rasters, has no stock
/// gdistance equivalent (its type "r" correction also stretches the costs).
public struct RandomizedShortestPaths: Sendable {

    /// The cell graph.
    public let graph: CellGraph
    /// How strongly walkers favour cheap paths, in reciprocal cost units.
    public let theta: Double

    /// The walk's weight on each step, W = P ∘ exp(−θ C), in the graph's step order.
    private let transitions: [Double]
    /// The position of each step's reverse, in the graph's step order.
    private let reverseSteps: [Int]

    /// Prepares RSP distances on a cell graph.
    ///
    /// - Parameters:
    ///   - graph: The cell graph.
    ///   - theta: θ, zero or more.
    /// - Returns: `nil` if `theta` is negative or not finite.
    public init?(graph: CellGraph, theta: Double) {
        guard theta.isFinite, theta >= 0 else { return nil }
        self.graph = graph
        self.theta = theta
        var transitions = [Double](repeating: 0, count: graph.targets.count)
        var reverseSteps = [Int](repeating: 0, count: graph.targets.count)
        for node in 0 ..< graph.nodeCount {
            let steps = graph.steps(from: node)
            let total = steps.reduce(0) { $0 + graph.walkWeights[$1] }
            for step in steps {
                transitions[step] = graph.walkWeights[step] / total * exp(-theta * graph.costs[step])
                let neighbour = Int(graph.targets[step])
                reverseSteps[step] = graph.steps(from: neighbour).first { Int(graph.targets[$0]) == node }!
            }
        }
        self.transitions = transitions
        self.reverseSteps = reverseSteps
    }

    /// The RSP distances from each origin to each destination.
    ///
    /// The distances are directed: entry `[i][j]` is from `origins[i]` to `destinations[j]`, and RSP
    /// distances needn't be symmetric. Average the two directions if a symmetric matrix is needed.
    ///
    /// - Parameters:
    ///   - origins: The nodes walks start from.
    ///   - destinations: The nodes walks are absorbed at.
    ///   - measure: Which distance to report.
    /// - Returns: An `origins.count × destinations.count` matrix, `0` from a node to itself and `.infinity`
    ///   between regions; or `nil` if a node is out of range, `measure` is ``Measure/freeEnergy`` with θ = 0,
    ///   or θ is so large for these costs that the walk's probabilities underflow.
    public func distances(from origins: [Int], to destinations: [Int], measure: Measure) -> [[Double]]? {
        guard (origins + destinations).allSatisfy({ $0 >= 0 && $0 < graph.nodeCount }),
              measure != .freeEnergy || theta > 0 else { return nil }
        var result = [[Double]](repeating: [Double](repeating: .infinity, count: destinations.count),
                                count: origins.count)
        var local = [Int32](repeating: -1, count: graph.nodeCount)
        for (column, destination) in destinations.enumerated() {
            let region = graph.regions[destination]
            let members = (0 ..< graph.nodeCount).filter { graph.regions[$0] == region }
            for (index, node) in members.enumerated() { local[node] = Int32(index) }
            defer { for node in members { local[node] = -1 } }

            let rows = origins.indices.filter { origins[$0] != destination && graph.regions[origins[$0]] == region }
            for row in origins.indices where origins[row] == destination { result[row][column] = 0 }
            guard !rows.isEmpty else { continue }
            guard let values = distances(from: rows.map { origins[$0] }, to: destination, members: members,
                                         local: local, measure: measure) else { return nil }
            for (row, value) in zip(rows, values) { result[row][column] = value }
        }
        return result
    }

    /// The distances from several origins to one destination, solving on the destination's region.
    private func distances(from origins: [Int], to destination: Int, members: [Int], local: [Int32],
                           measure: Measure) -> [Double]? {
        let size = members.count
        let target = Int(local[destination])
        let system = absorbingSystem(members: members, local: local, target: target)
        var unit = [Double](repeating: 0, count: size)
        unit[target] = 1
        var originUnits: [Double] = []
        if measure != .freeEnergy {
            originUnits = [Double](repeating: 0, count: size * origins.count)
            for (index, origin) in origins.enumerated() { originUnits[index * size + Int(local[origin])] = 1 }
        }
        guard let (towardTarget, fromOrigins) = system.solve(unit, transposed: originUnits) else { return nil }

        var distances: [Double] = []
        for (index, origin) in origins.enumerated() {
            let reach = towardTarget[Int(local[origin])]
            // z_it is the weight of every walk from i absorbed at t; zero means θ·cost has underflowed.
            guard reach >= Double.leastNormalMagnitude else { return nil }
            switch measure {
            case .freeEnergy:
                distances.append(-log(reach) / theta)
            case .expectedCost, .netExpectedCost:
                let row = fromOrigins[index * size ..< (index + 1) * size]
                distances.append(passageCost(row: Array(row), toward: towardTarget, members: members, local: local,
                                             target: target, net: measure == .netExpectedCost) / reach)
            }
        }
        return distances
    }

    /// I − W restricted to a region, with the target's row of W zeroed, in compressed columns.
    private func absorbingSystem(members: [Int], local: [Int32], target: Int) -> SparseSquareSystem {
        var columnStarts = [0]
        var rowIndices: [Int32] = []
        var values: [Double] = []
        columnStarts.reserveCapacity(members.count + 1)
        for (column, node) in members.enumerated() {
            var diagonalPlaced = false
            for step in graph.steps(from: node) {
                // Column `column` holds −W[k, column] for each neighbour k: the weight of k's step back here.
                let row = Int(local[Int(graph.targets[step])])
                if !diagonalPlaced && row > column {
                    rowIndices.append(Int32(column))
                    values.append(1)
                    diagonalPlaced = true
                }
                guard row != target else { continue }
                rowIndices.append(Int32(row))
                values.append(-transitions[reverseSteps[step]])
            }
            if !diagonalPlaced {
                rowIndices.append(Int32(column))
                values.append(1)
            }
            columnStarts.append(rowIndices.count)
        }
        return SparseSquareSystem(size: members.count, columnStarts: columnStarts, rowIndices: rowIndices,
                                  values: values)
    }

    /// Σ cost × expected passages for one origin, before dividing by z_it.
    ///
    /// - Parameters:
    ///   - row: The origin's row of Z.
    ///   - toward: The column of Z towards the target.
    ///   - net: Whether to count net flow (forward minus back, where positive) instead of total flow.
    private func passageCost(row: [Double], toward: [Double], members: [Int], local: [Int32], target: Int,
                             net: Bool) -> Double {
        var sum = 0.0
        for (k, node) in members.enumerated() where k != target || net {
            for step in graph.steps(from: node) {
                let l = Int(local[Int(graph.targets[step])])
                let forward = k == target ? 0 : row[k] * transitions[step] * toward[l]
                if net {
                    guard k < l else { continue }
                    let back = l == target ? 0 : row[l] * transitions[reverseSteps[step]] * toward[k]
                    sum += graph.costs[step] * abs(forward - back)
                } else {
                    sum += graph.costs[step] * forward
                }
            }
        }
        return sum
    }
}
