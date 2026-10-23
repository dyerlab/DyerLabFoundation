//
//  RandomizeGraph.swift
//  DyerLabFoundation
//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  A port of gstudio's `randomize_graph()` — an edge-randomised copy of a
//  graph, either fully (`.full`) or preserving the degree sequence (`.degree`).
//  Uses ``RMersenneTwister``. `.full` reproduces R's
//  `set.seed(seed); randomize_graph(graph, "full")` exactly; `.degree` is a
//  functional (not RNG-exact) port of gstudio >= 1.15's
//  `igraph::rewire(keeping_degseq())` edge-swap chain.
//  See `~/Coding/gstudio/R/randomize_graph.R`.
//

import Matrix
import Foundation

/// The randomisation strategy for ``RandomizeGraph(graph:mode:seed:)``.
public enum GraphRandomization: Sendable {
    /// Shuffle which node pairs are connected, keeping the edge count. The
    /// result is unweighted and its degree sequence is not preserved.
    case full
    /// Rewire by repeated degree-preserving edge swaps (`10 × edges` attempts),
    /// rejecting any swap that would create a self-loop or a multi-edge. Every
    /// node keeps its degree, the result is always a simple graph, and the
    /// original vertex order is kept.
    case degree
}

/// Returns an edge-randomised copy of `graph` — a port of gstudio's
/// `randomize_graph()`.
///
/// With the same `seed` and input graph, `.full` reproduces R's
/// `set.seed(seed); randomize_graph(graph, mode = "full")` exactly, because the
/// sampling runs through `RMersenneTwister`. `.degree` follows the same
/// edge-swap chain as gstudio's `igraph::rewire(keeping_degseq())` but does not
/// reproduce igraph's individual random draws.
///
/// - Parameters:
///   - graph: The graph to randomise. Node order is significant for `.full` — it
///     fixes the adjacency-matrix order R's sampling consumes.
///   - mode: `.degree` (default, preserves the degree sequence) or `.full`.
///   - seed: The RNG seed, equivalent to R's `set.seed(seed)`.
/// - Returns: The randomised graph. (Optional for source compatibility; neither
///   mode currently fails.)
public func RandomizeGraph(graph: Graph,
                           mode: GraphRandomization = .degree,
                           seed: Int) -> Graph? {
    var rng = RMersenneTwister(seed: seed)
    return randomizeGraph(graph, mode: mode, using: &rng)
}

/// The RNG-threaded core, so callers that randomise repeatedly (e.g.
/// ``AsymmetryNetworkTest(graph:permutations:rewire:seed:)``) keep a single
/// generator state across iterations, exactly as R does.
func randomizeGraph(_ graph: Graph,
                    mode: GraphRandomization,
                    using rng: inout RMersenneTwister) -> Graph? {
    switch mode {
    case .full:
        return randomizeFull(graph, using: &rng)
    case .degree:
        return randomizeDegree(graph, using: &rng)
    }
}

// MARK: - .full

private func randomizeFull(_ graph: Graph, using rng: inout RMersenneTwister) -> Graph {
    let names = graph.nodes.map { $0.name }
    let k = names.count
    let adjacency = graph.undirectedAdjacency()

    // Column-major lower triangle, matching R's `e[lower.tri(e)]`.
    var values: [Double] = []
    for col in 0..<k {
        for row in (col + 1)..<k {
            values.append(adjacency[names[row]]?[names[col]] != nil ? 1.0 : 0.0)
        }
    }

    let shuffled = rng.sample(values)

    // Refill the lower triangle in the same column-major order, symmetrise.
    var newAdjacency = [[Double]](repeating: [Double](repeating: 0.0, count: k), count: k)
    var index = 0
    for col in 0..<k {
        for row in (col + 1)..<k {
            newAdjacency[row][col] = shuffled[index]
            newAdjacency[col][row] = shuffled[index]
            index += 1
        }
    }

    // Preserve the original vertex set and order (R drops names here; keeping
    // them is strictly more useful and topologically identical).
    let newNodes = graph.nodes.map { source -> Node in
        let copy = Node(name: source.name, size: source.size, color: source.color,
                        categoricalAttributes: source.categoricalAttributes,
                        continuousAttributes: source.continuousAttributes)
        if let coordinate = source.coordinate { copy.coordinate = coordinate }
        return copy
    }
    var edges: [Edge] = []
    for i in 0..<k {
        for j in (i + 1)..<k where newAdjacency[i][j] != 0.0 {
            edges.append(Edge(fromNode: newNodes[i], toNode: newNodes[j], weight: 1.0))
        }
    }
    return Graph(nodes: newNodes, edges: edges)
}

// MARK: - .degree

private func randomizeDegree(_ graph: Graph, using rng: inout RMersenneTwister) -> Graph? {
    // R (gstudio >= 1.15): igraph::rewire(graph, keeping_degseq(loops = FALSE,
    // niter = 10 * ecount)). A functional port of that degree-preserving
    // edge-swap (Maslov-Sneppen) chain, not an RNG-exact one: the same seed does
    // not reproduce igraph's draws, but the chain — and so the null it samples —
    // is the same.
    let names = graph.nodes.map { $0.name }
    let indexOf = Dictionary(uniqueKeysWithValues: names.enumerated().map { ($1, $0) })

    // Edges as vertex-index pairs, lower index first (igraph's canonical
    // undirected orientation). Swaps rewrite these slots in place, so edge order
    // is preserved, as in igraph.
    var edges: [(Int, Int)] = graph.undirectedEdgeList().compactMap { edge in
        guard let a = indexOf[edge.from], let b = indexOf[edge.to] else { return nil }
        return (min(a, b), max(a, b))
    }
    let edgeCount = edges.count

    func key(_ u: Int, _ v: Int) -> Int { min(u, v) * names.count + max(u, v) }
    var present = Set(edges.map { key($0.0, $0.1) })

    if edgeCount >= 2 {
        for _ in 0..<(10 * edgeCount) {
            // Two distinct edges, uniformly.
            let first = rng.unifIndex(edgeCount)
            var second = rng.unifIndex(edgeCount - 1)
            if second >= first { second += 1 }

            let (a, b) = edges[first]
            var (c, d) = edges[second]
            // Either pairing, (a,d)+(c,b) or (a,c)+(b,d), with equal probability.
            if rng.unifRand() < 0.5 { swap(&c, &d) }

            // Reject swaps that would create a self-loop or a multi-edge.
            if a == d || c == b { continue }
            if present.contains(key(a, d)) || present.contains(key(c, b)) { continue }

            present.remove(key(a, b))
            present.remove(key(c, d))
            present.insert(key(a, d))
            present.insert(key(c, b))
            edges[first] = (min(a, d), max(a, d))
            edges[second] = (min(c, b), max(c, b))
        }
    }

    // Original vertex set and order; swapped edges carry no meaningful weight,
    // so the result is a bare (unit-weight) topology, as in R.
    let newNodes = graph.nodes.map { source -> Node in
        let copy = Node(name: source.name, size: source.size, color: source.color,
                        categoricalAttributes: source.categoricalAttributes,
                        continuousAttributes: source.continuousAttributes)
        if let coordinate = source.coordinate { copy.coordinate = coordinate }
        return copy
    }
    let newEdges = edges.map { Edge(fromNode: newNodes[$0.0], toNode: newNodes[$0.1], weight: 1.0) }
    return Graph(nodes: newNodes, edges: newEdges)
}
