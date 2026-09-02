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
//  Uses ``RMersenneTwister`` so that, given the same seed and input graph, the
//  output is identical to R's `set.seed(seed); randomize_graph(graph, mode)`.
//  See `~/Coding/gstudio/R/randomize_graph.R`.
//

import Matrix
import Foundation

/// The randomisation strategy for ``RandomizeGraph(graph:mode:seed:)``.
public enum GraphRandomization: Sendable {
    /// Shuffle which node pairs are connected, keeping the edge count. The
    /// result is unweighted and its degree sequence is not preserved.
    case full
    /// Rewire endpoints so every node keeps its original degree. The result may
    /// contain parallel edges (matching R, whose duplicate check is on directed
    /// pairs).
    case degree
}

/// Returns an edge-randomised copy of `graph` — a port of gstudio's
/// `randomize_graph()`.
///
/// With the same `seed` and input graph this reproduces R's
/// `set.seed(seed); randomize_graph(graph, mode = "...")` exactly, because the
/// sampling runs through ``RMersenneTwister``.
///
/// - Parameters:
///   - graph: The graph to randomise. Node order is significant — it fixes the
///     adjacency-matrix / edge-list order R's sampling consumes.
///   - mode: `.degree` (default, preserves the degree sequence) or `.full`.
///   - seed: The RNG seed, equivalent to R's `set.seed(seed)`.
/// - Returns: The randomised graph, or `nil` if `.degree` mode cannot find a
///   valid rewiring within 10000 attempts (matching R's error).
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
    // R: e <- as_edgelist(graph); one (from, to) row per undirected edge in
    // edge-id order.
    let edgeList = graph.undirectedEdgeList()
    guard !edgeList.isEmpty else { return Graph(nodes: [], edges: []) }

    let v1 = edgeList.map { $0.from }.sorted()          // R: sort(e[,1]) — C-locale / ASCII
    let v2 = rng.sample(edgeList.map { $0.to })          // R: v2 <- sample(e[,2])

    func invalid(_ pairs: [(String, String)]) -> Bool {
        if pairs.contains(where: { $0.0 == $0.1 }) { return true }   // self-loop
        var seen = Set<String>()
        for (a, b) in pairs {
            let key = "\(a)\u{1}\(b)"                                 // directed row, as R's duplicated()
            if !seen.insert(key).inserted { return true }
        }
        return false
    }

    var pairs = Array(zip(v1, v2))
    var attempts = 0
    while invalid(pairs) {
        // R: new_edges <- cbind(v1, sample(v2, ...)) — each retry re-shuffles
        // the SAME first-sampled v2, not the previous attempt's arrangement.
        pairs = Array(zip(v1, rng.sample(v2)))
        attempts += 1
        if attempts > 10000 { return nil }
    }

    // R: graph_from_edgelist(new_edges, directed = FALSE) — vertices in order of
    // first appearance; one edge per row (parallel edges allowed).
    var order: [String] = []
    var nodeByName: [String: Node] = [:]
    func node(_ name: String) -> Node {
        if let existing = nodeByName[name] { return existing }
        let source = graph.node(name: name)
        let created = Node(name: name, size: source?.size ?? 1.0, color: source?.color ?? .red,
                           categoricalAttributes: source?.categoricalAttributes ?? [:],
                           continuousAttributes: source?.continuousAttributes ?? [:])
        if let coordinate = source?.coordinate { created.coordinate = coordinate }
        nodeByName[name] = created
        order.append(name)
        return created
    }

    // Realise the vertex set (first-appearance order) before emitting edges so
    // each edge's endpoints can be ordered by vertex index — matching igraph's
    // canonical undirected representation (`as_edgelist` returns min-id first).
    for (a, b) in pairs { _ = node(a); _ = node(b) }
    let position = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })

    var edges: [Edge] = []
    for (a, b) in pairs {
        let (lo, hi) = position[a]! <= position[b]! ? (a, b) : (b, a)
        edges.append(Edge(fromNode: nodeByName[lo]!, toNode: nodeByName[hi]!, weight: 1.0))
    }
    return Graph(nodes: order.map { nodeByName[$0]! }, edges: edges)
}
