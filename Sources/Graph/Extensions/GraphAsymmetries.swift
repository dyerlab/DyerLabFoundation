//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GraphAsymmetries.swift
//  Graph
//
//  A direct port of gstudio's `graph_asymmetries()` — directional introgression
//  pressures and a per-edge asymmetry index for a weighted population graph,
//  from a local Gaussian kernel over each node's neighbourhood.
//  See `~/Coding/gstudio/R/graph_asymmetries.R`.
//
//  Created by Rodney Dyer on 2026.09.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import Foundation

/// How ``GraphAsymmetries(graph:bandwidth:scale:)`` sets the per-node kernel
/// bandwidth `bᵢ`.
public enum GraphBandwidth: Sendable {
    /// The canonical local estimator `bᵢ = sᵢ / kᵢ` (mean incident edge weight).
    case local
    /// A single fixed bandwidth applied to every node.
    case fixed(Double)
    /// A custom bandwidth per node, keyed by node name. Every node in the graph
    /// must have an entry.
    case perNode([String: Double])
}

/// The directional weights for one undirected edge `(from, to)`.
public struct DirectionalEdge: Sendable, Equatable {
    /// The first endpoint, as ordered by ``Graph/undirectedEdgeList()``.
    public let from: String
    /// The second endpoint.
    public let to: String
    /// `w_{from→to}`: the conditional probability that genetic signal
    /// originating at `from` reaches `to` rather than any other neighbour of
    /// `from`.
    public let wAway: Double
    /// `w_{to→from}`: the same quantity in the reverse direction.
    public let wTo: Double
    /// The asymmetry index `Δ = wAway − wTo`, in `(−1, 1)`. Positive means net
    /// introgression pressure from `from` toward `to`.
    public let delta: Double
}

/// The result of ``GraphAsymmetries(graph:bandwidth:scale:)``.
public struct GraphAsymmetryResult: Sendable {
    /// The kernel bandwidth used for each node, keyed by node name.
    public let bandwidth: [String: Double]
    /// One entry per undirected edge, in ``Graph/undirectedEdgeList()`` order.
    public let edges: [DirectionalEdge]
}

/// Computes directional introgression pressures and an asymmetry index for
/// every edge of an undirected, weighted graph — a port of gstudio's
/// `graph_asymmetries()`.
///
/// For each node `i` a local bandwidth `bᵢ` is the mean weight of its incident
/// edges (`strength / degree`). A Gaussian kernel over `i`'s neighbourhood,
/// normalised to sum to one, gives the conditional probability `w_{i→j}` for
/// each neighbour `j`. The per-edge asymmetry index is
/// `Δᵢⱼ = w_{i→j} − w_{j→i}`.
///
/// - Parameters:
///   - graph: An undirected, weighted graph. Parallel/`symmetric` edge pairs
///     are collapsed to a single undirected edge.
///   - bandwidth: How to set each node's kernel bandwidth (default `.local`).
///   - scale: A positive multiplier applied to every node's bandwidth
///     (default `1`), for bandwidth-sensitivity analysis — gstudio's `scale`, or
///     its alias `gamma` (`bᵢ = γ · sᵢ/kᵢ`). `.infinity` gives the flat kernel
///     (every neighbourhood weight `1/kᵢ`), at which `Δ` depends on degree alone.
/// - Returns: A ``GraphAsymmetryResult``, or `nil` if `scale` is not positive,
///   a `.perNode` map omits a node, or (for a finite `scale`) any *connected*
///   node's bandwidth is not finite and positive — matching gstudio, where
///   `graph_asymmetries()` stops on such input. Isolated nodes are allowed;
///   their bandwidth is reported as `.nan` and they contribute no edges.
public func GraphAsymmetries(graph: Graph,
                             bandwidth: GraphBandwidth = .local,
                             scale: Double = 1.0) -> GraphAsymmetryResult? {

    guard !scale.isNaN, scale > 0 else { return nil }
    let flat = scale.isInfinite

    let names = graph.nodes.map { $0.name }
    let adjacency = graph.undirectedAdjacency()
    let indexOf = Dictionary(uniqueKeysWithValues: names.enumerated().map { ($1, $0) })

    var b: [String: Double] = [:]
    for name in names {
        let degree = adjacency[name]?.count ?? 0
        let base: Double
        switch bandwidth {
        case .local:
            // R: ifelse(deg > 0, strength / deg, NA). Summed in ascending
            // neighbour-index order: Dictionary iteration order is not stable
            // across instances, and a reordered sum can differ in the last ULP.
            let strength = (adjacency[name] ?? [:])
                .sorted { (indexOf[$0.key] ?? 0) < (indexOf[$1.key] ?? 0) }
                .reduce(0.0) { $0 + $1.value }
            base = degree > 0 ? strength / Double(degree) : .nan
        case .fixed(let value):
            base = value
        case .perNode(let map):
            guard let value = map[name] else { return nil }
            base = value
        }
        let value = base * scale
        if !flat && degree > 0 && !(value.isFinite && value > 0) { return nil }
        b[name] = value
    }

    return GraphAsymmetryResult(bandwidth: b,
                                edges: directionalEdges(of: graph, bandwidth: b, adjacency: adjacency,
                                                        flat: flat))
}

/// The per-edge directional weights `(w_away, w_to, delta)` for an arbitrary
/// bandwidth vector `b` (keyed by node name), in ``Graph/undirectedEdgeList()``
/// order.
///
/// This is the kernel-normalisation + per-edge lookup shared by
/// ``GraphAsymmetries(graph:bandwidth:scale:)`` and the bandwidth-permutation
/// null (gstudio's `.delta_with_bandwidth()`).
///
/// - Parameters:
///   - graph: An undirected, weighted graph.
///   - b: Kernel bandwidth per node name.
///   - adjacency: A precomputed ``Graph/undirectedAdjacency()``, to skip rebuilding it.
///   - flat: Use the flat kernel instead of the bandwidth-scaled one.
/// - Returns: One directional edge per undirected edge.
func directionalEdges(of graph: Graph,
                      bandwidth b: [String: Double],
                      adjacency: [String: [String: Double]]? = nil,
                      flat: Bool = false) -> [DirectionalEdge] {
    let adjacency = adjacency ?? graph.undirectedAdjacency()

    // Neighbours are visited in ascending node-index order and the kernel's
    // normalising sum is accumulated in that same order, so the result is
    // bit-identical to igraph/R's `.delta_with_bandwidth()` (whose `neighbors()`
    // returns ascending vertex ids and whose `sum(k)` folds left to right) —
    // the bandwidth-permutation p-value is a threshold count and is sensitive
    // to the last ULP.
    let indexOf = Dictionary(uniqueKeysWithValues: graph.nodes.enumerated().map { ($1.name, $0) })

    var kernel: [String: [String: Double]] = [:]
    for (name, neighbors) in adjacency {
        guard !neighbors.isEmpty, let bw = b[name] else { continue }
        if flat {
            let share = 1.0 / Double(neighbors.count)
            kernel[name] = neighbors.mapValues { _ in share }
            continue
        }
        let bandwidthSquared = bw * bw
        let ordered = neighbors.sorted { (indexOf[$0.key] ?? 0) < (indexOf[$1.key] ?? 0) }
        let z = ordered.map { ($0.value * $0.value) / (2.0 * bandwidthSquared) }
        var k = z.map { exp(-$0) }
        var total = k.reduce(0, +)

        // R falls back to log-sum-exp (minimum exponent subtracted) only when the
        // plain kernel underflows, so ordinary results stay bit-identical.
        let zMin = z.min() ?? 0.0
        let underflow = !total.isFinite || total <= 0
            || zip(z, k).contains { $0.0 == zMin && $0.1 == 0 }
        if underflow {
            k = z.map { exp(-($0 - zMin)) }
            total = k.reduce(0, +)
        }
        kernel[name] = Dictionary(uniqueKeysWithValues: zip(ordered, k).map { ($0.0.key, $0.1 / total) })
    }

    return graph.undirectedEdgeList().map { edge -> DirectionalEdge in
        let wAway = kernel[edge.from]?[edge.to] ?? 0.0
        let wTo = kernel[edge.to]?[edge.from] ?? 0.0
        return DirectionalEdge(from: edge.from, to: edge.to, wAway: wAway, wTo: wTo, delta: wAway - wTo)
    }
}
