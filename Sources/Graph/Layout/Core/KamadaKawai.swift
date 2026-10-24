//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  KamadaKawai.swift
//  Graph
//
//  Kamada–Kawai stress layout, ported from igraph's igraph_layout_kamada_kawai().
//
//  Created by Rodney Dyer on 2026.10.21.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import Foundation

/// Kamada–Kawai layout solver: a line-for-line port of igraph's 2D
/// `igraph_layout_kamada_kawai()`, which R's `igraph::layout_with_kk()` calls,
/// so the same graph, weights and starting layout reproduce R's coordinates.
///
/// The model connects every pair of nodes `i, j` with a spring whose rest length
/// is proportional to their shortest-path distance `d_ij` and whose stiffness is
/// `kkconst / d_ij²`. Each move picks the node with the largest energy gradient
/// and takes one 2D Newton–Raphson step for it alone. Because every pair is
/// sprung — not just adjacent ones — Kamada–Kawai tends to spread clusters
/// further apart than Fruchterman–Reingold, which only attracts along edges.
///
/// Defaults follow `layout_with_kk()`: start on a circle of radius `0.36·√n`,
/// `maxIterations = 50·n` moves, `epsilon = 0`, `kkconst = n`. Disconnected node
/// pairs get the largest finite distance, as in igraph.
///
/// ```swift
/// var solver = try KamadaKawaiSolver(graph: graph, weighting: .flooredEdgeWeights())
/// solver.run()
/// let xy = solver.positions   // same units as R's layout_with_kk()
/// ```
public struct KamadaKawaiSolver: Sendable {

    /// Number of nodes being laid out.
    public let nodeCount: Int

    /// Moves taken so far in the current run.
    public private(set) var iteration: Int = 0

    /// Moves allowed before the run stops.
    public var maxIterations: Int

    /// The run stops early once the largest squared gradient falls below this.
    /// igraph's default of `0` means it always takes `maxIterations` moves.
    public var epsilon: Double

    /// Squared energy gradient of the node selected by the most recent move.
    public private(set) var maxDelta: Double = .infinity

    /// Distance the most recent move carried its node, in layout units.
    public private(set) var lastMoveDistance: Double = 0

    /// Whether the run has used its move budget or converged below `epsilon`.
    public private(set) var isFinished: Bool = false

    /// Nodes held at a fixed position. A selected fixed node is clamped back
    /// to its target, which is igraph's `minx == maxx`, `miny == maxy` limit.
    public var fixedPositions: [Int: SIMD2<Double>] = [:]

    private var x: [Double]
    private var y: [Double]
    /// Spring stiffness `kkconst / d_ij²`, row-major `n × n`.
    private let kij: [Double]
    /// Spring rest length `L · d_ij`, row-major `n × n`.
    private let lij: [Double]
    private var d1: [Double]
    private var d2: [Double]

    /// Below this gradient a node is at equilibrium and is not moved.
    private static let equilibriumEpsilon = 1e-13

    /// Current node positions, in node order.
    public var positions: [SIMD2<Double>] {
        (0..<nodeCount).map { SIMD2(x[$0], y[$0]) }
    }

    /// Creates a solver from a precomputed distance matrix.
    ///
    /// - Parameters:
    ///   - distances: Symmetric `n × n` shortest-path distances. Infinite
    ///     entries (disconnected pairs) are replaced by the largest finite one.
    ///   - initial: Starting positions; `nil` uses igraph's circle of radius
    ///     `0.36·√n`.
    ///   - maxIterations: Move budget; `nil` uses `50·n`.
    ///   - epsilon: Early-stop threshold on the squared gradient.
    ///   - kkconst: Spring constant; `nil` uses `max(n, 1)`.
    public init(distances: Matrix,
                initial: [SIMD2<Double>]? = nil,
                maxIterations: Int? = nil,
                epsilon: Double = 0,
                kkconst: Double? = nil) {
        let n = distances.rows
        self.nodeCount = n
        self.maxIterations = maxIterations ?? 50 * n
        self.epsilon = epsilon
        let constant = kkconst ?? Double(max(n, 1))
        let l0 = Double(n).squareRoot()

        if let initial, initial.count == n {
            x = initial.map(\.x)
            y = initial.map(\.y)
        } else {
            x = Array(repeating: 0, count: n)
            y = Array(repeating: 0, count: n)
            let radius = 0.36 * l0
            for i in 0..<n {
                let phi = 2 * Double.pi / Double(n) * Double(i)
                x[i] = cos(phi) * radius
                y[i] = sin(phi) * radius
            }
        }

        // Largest finite distance; disconnected pairs are set to it.
        var dij = [Double](repeating: 0, count: n * n)
        var maxDij = 0.0
        for i in 0..<n {
            for j in 0..<n {
                let d = distances[i, j]
                dij[i * n + j] = d
                if i != j, d.isFinite, d > maxDij { maxDij = d }
            }
        }
        // igraph leaves an edgeless graph with 0/0 springs (NaN coordinates);
        // treat every pair as one unit apart instead so it lays out as a circle.
        if maxDij == 0 {
            maxDij = 1
            for i in 0..<n { for j in 0..<n where i != j { dij[i * n + j] = 1 } }
        }
        for k in 0..<(n * n) where dij[k] > maxDij { dij[k] = maxDij }

        let scale = l0 / maxDij
        var k = [Double](repeating: 0, count: n * n)
        var l = [Double](repeating: 0, count: n * n)
        for i in 0..<n {
            for j in 0..<n where i != j {
                let d = dij[i * n + j]
                k[i * n + j] = constant / (d * d)
                l[i * n + j] = scale * d
            }
        }
        kij = k
        lij = l

        d1 = Array(repeating: 0, count: n)
        d2 = Array(repeating: 0, count: n)
        for i in 0..<n {
            for m in 0..<n where i != m {
                let dx = x[m] - x[i]
                let dy = y[m] - y[i]
                let dist = (dx * dx + dy * dy).squareRoot()
                d1[m] += k[m * n + i] * (dx - l[m * n + i] * dx / dist)
                d2[m] += k[m * n + i] * (dy - l[m * n + i] * dy / dist)
            }
        }

        if n <= 1 { isFinished = true }
    }

    /// Creates a solver for `graph`, deriving distances from its undirected
    /// edge weights.
    ///
    /// - Parameters:
    ///   - graph: The graph to lay out.
    ///   - weighting: How edge weights become spring lengths.
    ///   - initial: Starting positions; `nil` uses igraph's circle.
    ///   - maxIterations: Move budget; `nil` uses `50·n`.
    ///   - epsilon: Early-stop threshold on the squared gradient.
    ///   - kkconst: Spring constant; `nil` uses `max(n, 1)`.
    /// - Throws: ``KamadaKawaiError/nonPositiveWeight(_:)`` if a resulting edge
    ///   length is zero or negative.
    public init(graph: Graph,
                weighting: KamadaKawaiWeighting = .flooredEdgeWeights(),
                initial: [SIMD2<Double>]? = nil,
                maxIterations: Int? = nil,
                epsilon: Double = 0,
                kkconst: Double? = nil) throws {
        let distances = try graph.kamadaKawaiDistances(weighting: weighting)
        self.init(distances: distances, initial: initial, maxIterations: maxIterations,
                  epsilon: epsilon, kkconst: kkconst)
    }

    /// Current position of one node.
    ///
    /// - Parameter node: The node's index.
    /// - Returns: The node's position in layout units.
    public func position(_ node: Int) -> SIMD2<Double> {
        SIMD2(x[node], y[node])
    }

    /// Spring rest length between two nodes, in layout units.
    ///
    /// - Parameters:
    ///   - i: The first node's index.
    ///   - j: The second node's index.
    /// - Returns: The rest length.
    public func idealLength(_ i: Int, _ j: Int) -> Double {
        lij[i * nodeCount + j]
    }

    /// Takes one move: the node with the largest gradient takes a Newton step.
    ///
    /// - Returns: `false` once the run is finished and no move was made.
    @discardableResult
    public mutating func step() -> Bool {
        guard !isFinished else { return false }
        guard iteration < maxIterations else {
            isFinished = true
            return false
        }
        let n = nodeCount

        var m = 0
        var best = -1.0
        for i in 0..<n {
            let delta = d1[i] * d1[i] + d2[i] * d2[i]
            if delta > best {
                m = i
                best = delta
            }
        }
        maxDelta = best
        if best < epsilon {
            isFinished = true
            return false
        }

        let oldX = x[m]
        let oldY = y[m]
        var a = 0.0, b = 0.0, c = 0.0
        for i in 0..<n where i != m {
            let dx = oldX - x[i]
            let dy = oldY - y[i]
            let dist = (dx * dx + dy * dy).squareRoot()
            let den = dist * (dx * dx + dy * dy)
            let kmi = kij[m * n + i]
            let lmi = lij[m * n + i]
            a += kmi * (1 - lmi * dy * dy / den)
            b += kmi * lmi * dx * dy / den
            c += kmi * (1 - lmi * dx * dx / den)
        }
        let myD1 = d1[m]
        let myD2 = d2[m]

        // Solve  a·Δx + b·Δy = myD1,  b·Δx + c·Δy = myD2  (eqs. 11–12 of the
        // paper), skipping nodes already at equilibrium: on a path graph the
        // system is singular there.
        var deltaX = 0.0
        var deltaY = 0.0
        if myD1 * myD1 + myD2 * myD2 >= Self.equilibriumEpsilon * Self.equilibriumEpsilon {
            let det = c * a - b * b
            deltaY = (b * myD1 - a * myD2) / det
            deltaX = (b * myD2 - c * myD1) / det
        }

        var target = SIMD2(oldX + deltaX, oldY + deltaY)
        if let fixed = fixedPositions[m] { target = fixed }
        let shift = target - SIMD2(oldX, oldY)
        lastMoveDistance = (shift * shift).sum().squareRoot()
        relocate(m, to: target)

        iteration += 1
        if iteration >= maxIterations { isFinished = true }
        return true
    }

    /// Runs moves until the budget is spent or the layout converges.
    public mutating func run() {
        while step() {}
    }

    /// Moves a node directly, keeping the gradients consistent. Used to follow
    /// a node being dragged.
    ///
    /// - Parameters:
    ///   - node: The node's index; out-of-range indices are ignored.
    ///   - position: The new position.
    public mutating func move(_ node: Int, to position: SIMD2<Double>) {
        guard node >= 0, node < nodeCount, position != SIMD2(x[node], y[node]) else { return }
        relocate(node, to: position)
    }

    /// Grants a fresh move budget, continuing from the current positions
    /// (igraph's `use_seed = true`).
    ///
    /// - Parameter moves: The new budget; `nil` uses `50·n`.
    public mutating func extendBudget(_ moves: Int? = nil) {
        iteration = 0
        maxIterations = moves ?? 50 * nodeCount
        isFinished = nodeCount <= 1
    }

    /// Moves node `m` to `position` and updates every node's gradient for the
    /// change — igraph's "update delta, only with/for the affected node".
    private mutating func relocate(_ m: Int, to position: SIMD2<Double>) {
        let n = nodeCount
        let oldX = x[m], oldY = y[m]
        let newX = position.x, newY = position.y
        d1[m] = 0
        d2[m] = 0
        for i in 0..<n where i != m {
            let oldDx = oldX - x[i]
            let oldDy = oldY - y[i]
            let oldDist = (oldDx * oldDx + oldDy * oldDy).squareRoot()
            let newDx = newX - x[i]
            let newDy = newY - y[i]
            let newDist = (newDx * newDx + newDy * newDy).squareRoot()
            let kmi = kij[m * n + i]
            let lmi = lij[m * n + i]

            d1[i] -= kmi * (-oldDx + lmi * oldDx / oldDist)
            d2[i] -= kmi * (-oldDy + lmi * oldDy / oldDist)
            d1[i] += kmi * (-newDx + lmi * newDx / newDist)
            d2[i] += kmi * (-newDy + lmi * newDy / newDist)

            d1[m] += kmi * (newDx - lmi * newDx / newDist)
            d2[m] += kmi * (newDy - lmi * newDy / newDist)
        }
        x[m] = newX
        y[m] = newY
    }
}

public extension Graph {

    /// Runs a full Kamada–Kawai layout and returns one position per node, in
    /// `nodes` order — the equivalent of `igraph::layout_with_kk()`.
    ///
    /// With the default ``KamadaKawaiWeighting/flooredEdgeWeights(medianFraction:)``
    /// this matches gstudio's `layout = "kk"`.
    ///
    /// - Parameters:
    ///   - weighting: How edge weights become spring lengths.
    ///   - initial: Starting positions; `nil` uses igraph's circle.
    ///   - maxIterations: Move budget; `nil` uses `50·n`.
    /// - Returns: One position per node.
    /// - Throws: ``KamadaKawaiError/nonPositiveWeight(_:)`` if an edge length is zero or negative.
    func kamadaKawaiLayout(weighting: KamadaKawaiWeighting = .flooredEdgeWeights(),
                           initial: [SIMD2<Double>]? = nil,
                           maxIterations: Int? = nil) throws -> [SIMD2<Double>] {
        var solver = try KamadaKawaiSolver(graph: self, weighting: weighting,
                                           initial: initial, maxIterations: maxIterations)
        solver.run()
        return solver.positions
    }

    /// All-pairs shortest-path distances under a Kamada–Kawai weighting.
    ///
    /// - Parameter weighting: How edge weights become spring lengths.
    /// - Returns: An `n × n` distance matrix in node order.
    /// - Throws: ``KamadaKawaiError/nonPositiveWeight(_:)`` if an edge length is zero or negative.
    internal func kamadaKawaiDistances(weighting: KamadaKawaiWeighting) throws -> Matrix {
        let edgeList = undirectedEdgeList()
        let lengths: [Double]
        switch weighting {
        case .unweighted:
            lengths = edgeList.map { _ in 1.0 }
        case .edgeWeights:
            lengths = edgeList.map(\.weight)
        case .flooredEdgeWeights(let fraction):
            let weights = edgeList.map(\.weight)
            var median = weights.isEmpty ? 1.0 : Self.median(weights)
            if !median.isFinite || median <= 0 { median = 1 }
            lengths = weights.map { $0 + fraction * median }
        }
        if let bad = lengths.first(where: { !($0 > 0) }) {
            throw KamadaKawaiError.nonPositiveWeight(bad)
        }

        let byName = Dictionary(uniqueKeysWithValues: nodes.map { ($0.name, $0) })
        let reweighted = zip(edgeList, lengths).compactMap { edge, length -> Edge? in
            guard let a = byName[edge.from], let b = byName[edge.to] else { return nil }
            return Edge(fromNode: a, toNode: b, weight: length)
        }
        return Graph(nodes: nodes, edges: reweighted).weightedDistanceMatrix()
    }

    /// R's `stats::median()`: the mean of the two middle values for even counts.
    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}
