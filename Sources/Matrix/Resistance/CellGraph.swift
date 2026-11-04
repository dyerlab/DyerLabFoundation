//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  CellGraph.swift
//  Matrix
//
//  The graph of a resistance raster's cells, on the raster's own grid: no
//  reprojection. Each passable cell is a node, joined to its 4 or 8
//  neighbours. A step costs its length times the mean resistance of the two
//  cells, the same costs as gdistance's
//
//      tr <- transition(r, function(x) 1 / mean(x), directions = 8)
//      tr <- geoCorrection(tr, type = "c")
//
//  The graph is held as compressed rows (each step stored once in each
//  direction), with neighbours in increasing node order, which is the order
//  the sparse solver wants.
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The graph of steps between the cells of a resistance raster, for least-cost and randomized-shortest-path
/// distances.
///
/// Cells with a missing value are impassable and left out. Every other cell must have a positive resistance.
/// A step between two cells costs its length (``StepLength``) times the mean of their resistances.
///
/// ```swift
/// let graph = CellGraph(resistance: surface)!
/// let sites = locations.compactMap { graph.node(longitude: $0.longitude, latitude: $0.latitude) }
/// let rsp = RandomizedShortestPaths(graph: graph, theta: 1e-3)!
/// let distances = rsp.distances(from: sites, to: sites, measure: .freeEnergy)
/// ```
///
/// ``notes`` records how the graph was built and warns when the raster's geometry makes the step lengths
/// less trustworthy, for the analysis log.
public struct CellGraph: Sendable {

    /// The resistance surface.
    public let resistance: Raster
    /// Which cells are joined.
    public let neighbours: Neighbours
    /// How step lengths are measured.
    public let stepLength: StepLength
    /// How the reference random walk moves.
    public let referenceWalk: ReferenceWalk
    /// The raster cell (`row * cols + col`) of each node, in increasing order.
    public let cells: [Int]
    /// The region of each node: two nodes are joined by some path exactly when their regions match.
    public let regions: [Int]
    /// The number of separate regions the passable cells form.
    public let regionCount: Int
    /// How the graph was built, and warnings about the raster's geometry.
    public let notes: [AnalysisNote]

    /// The node of each raster cell, or −1 for an impassable cell.
    let nodeOfCell: [Int32]
    /// Where each node's steps start in ``targets``, with a final entry for the total.
    let offsets: [Int]
    /// The node each step leads to.
    let targets: [Int32]
    /// The cost of each step.
    let costs: [Double]
    /// The reference walk's weight on each step, before normalising over a node's steps.
    let walkWeights: [Double]

    /// The number of nodes (passable cells).
    public var nodeCount: Int { cells.count }

    /// The number of steps between neighbouring nodes, each counted once.
    public var stepCount: Int { targets.count / 2 }

    /// Builds the cell graph of a resistance raster.
    ///
    /// - Parameters:
    ///   - resistance: The resistance of each cell. Missing (`NaN`) or infinite cells are impassable.
    ///   - neighbours: Which cells are joined (default ``Neighbours/eight``).
    ///   - stepLength: How step lengths are measured (default ``StepLength/ground``).
    ///   - referenceWalk: How the reference random walk moves (default ``ReferenceWalk/areaCorrected``).
    /// - Returns: `nil` if a resistance is zero or negative, or no cell is passable.
    public init?(resistance: Raster,
                 neighbours: Neighbours = .eight,
                 stepLength: StepLength = .ground,
                 referenceWalk: ReferenceWalk = .areaCorrected) {
        let values = resistance.values.map(Double.init)
        guard values.allSatisfy({ $0.isNaN || $0 > 0 }),
              let geometry = CellStepGeometry(raster: resistance, stepLength: stepLength) else { return nil }
        let (rows, cols) = (resistance.rows, resistance.cols)
        let passable = values.map(\.isFinite)

        var cells: [Int] = []
        var nodeOfCell = [Int32](repeating: -1, count: values.count)
        for cell in values.indices where passable[cell] {
            nodeOfCell[cell] = Int32(cells.count)
            cells.append(cell)
        }
        guard !cells.isEmpty else { return nil }

        // Neighbour offsets in raster order, so each node's steps come out in increasing node order.
        let moves: [(dr: Int, dc: Int)] = neighbours == .eight
            ? [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
            : [(-1, 0), (0, -1), (0, 1), (1, 0)]
        let areaCorrected = referenceWalk == .areaCorrected ? geometry.boundaryLatitudes : nil

        var offsets = [0]
        var targets: [Int32] = []
        var costs: [Double] = []
        var walkWeights: [Double] = []
        for cell in cells {
            let (row, col) = (cell / cols, cell % cols)
            for move in moves {
                let (r, c) = (row + move.dr, col + move.dc)
                guard r >= 0, r < rows, c >= 0, c < cols, passable[r * cols + c] else { continue }
                let upper = min(row, r)
                let length = move.dr == 0 ? geometry.eastWest[row]
                    : move.dc == 0 ? geometry.northSouth[upper] : geometry.diagonal[upper]
                let cost = length * (values[cell] + values[r * cols + c]) / 2
                let areaFactor = move.dr != 0 ? areaCorrected.map { cos($0[upper] * .pi / 180) } ?? 1 : 1
                targets.append(nodeOfCell[r * cols + c])
                costs.append(cost)
                walkWeights.append(areaFactor / cost)
            }
            offsets.append(targets.count)
        }

        self.resistance = resistance
        self.neighbours = neighbours
        self.stepLength = stepLength
        self.referenceWalk = referenceWalk
        self.cells = cells
        self.nodeOfCell = nodeOfCell
        self.offsets = offsets
        self.targets = targets
        self.costs = costs
        self.walkWeights = walkWeights
        (regions, regionCount) = Self.regions(offsets: offsets, targets: targets)
        notes = Self.notes(resistance: resistance, neighbours: neighbours, stepLength: stepLength,
                           referenceWalk: referenceWalk, impassable: values.count - cells.count,
                           regionCount: regionCount)
    }

    /// The steps leaving a node, as the positions of their entries in ``targets`` and ``costs``.
    func steps(from node: Int) -> Range<Int> { offsets[node] ..< offsets[node + 1] }

    /// The cost of the step between two neighbouring raster cells.
    ///
    /// - Parameters:
    ///   - cell: A raster cell, `row * cols + col`.
    ///   - neighbour: Another raster cell.
    /// - Returns: The cost, or `nil` if either cell is impassable or they aren't neighbours.
    public func stepCost(from cell: Int, to neighbour: Int) -> Double? {
        guard cell >= 0, cell < nodeOfCell.count, neighbour >= 0, neighbour < nodeOfCell.count else { return nil }
        let (from, to) = (nodeOfCell[cell], nodeOfCell[neighbour])
        guard from >= 0, to >= 0 else { return nil }
        return steps(from: Int(from)).first { targets[$0] == to }.map { costs[$0] }
    }

    /// Labels the connected regions of a graph by breadth-first search.
    private static func regions(offsets: [Int], targets: [Int32]) -> (labels: [Int], count: Int) {
        let nodeCount = offsets.count - 1
        var labels = [Int](repeating: -1, count: nodeCount)
        var count = 0
        var queue: [Int] = []
        for start in 0 ..< nodeCount where labels[start] < 0 {
            labels[start] = count
            queue = [start]
            var next = 0
            while next < queue.count {
                let node = queue[next]
                next += 1
                for step in offsets[node] ..< offsets[node + 1] {
                    let neighbour = Int(targets[step])
                    if labels[neighbour] < 0 {
                        labels[neighbour] = count
                        queue.append(neighbour)
                    }
                }
            }
            count += 1
        }
        return (labels, count)
    }
}
