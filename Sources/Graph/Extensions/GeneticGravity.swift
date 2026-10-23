//
//  GeneticGravity.swift
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
//  Ports of gstudio's (>= 1.15) genetic-gravity core: `neighbourhood_weights()`,
//  `gravity_edges()`, `source_sink_scores()`, and `pgd()` (partitioned
//  conditional genetic distance). One sign convention throughout: higher = more
//  of a source. See `~/Coding/gstudio/R/{neighbourhood_weights,gravity_edges,
//  source_sink_scores,pgd}.R` and the framework help page in `R/gravity.R`.
//
//  Node i's kernel bandwidth is b_i = gamma * s_i / k_i (strength over degree).
//  gamma = 0.5 (default) is degree-neutral, for inferring direction; gamma = 1
//  is the local mean, for describing connectivity; gamma = Inf is the flat,
//  degree-only kernel (w_{j|i} = 1/k_i).
//

import Matrix
import Foundation

// MARK: - neighbourhood_weights

/// The neighbourhood-weight matrix `W[i, j] = w_{j|i}` — population `j`'s weight
/// in `i`'s neighbourhood — a port of gstudio's `neighbourhood_weights()`.
///
/// Each row is a Gaussian kernel over node `i`'s neighbours with bandwidth
/// `bᵢ = γ · sᵢ/kᵢ`, normalised to sum to one (evaluated with the smallest
/// exponent subtracted, so it cannot underflow). Because `bᵢ` scales with the
/// edge weights, rescaling every weight by a constant leaves `W` unchanged.
///
/// - Parameters:
///   - graph: An undirected graph whose edge weights are conditional genetic
///     distances.
///   - gamma: Bandwidth multiplier (default `0.5`, degree-neutral); `1` is the
///     local mean and `.infinity` the flat kernel (`w_{j|i} = 1/kᵢ`).
/// - Returns: A `K × K` matrix in node order with node row/column names, `0`
///   for non-adjacent pairs and `.nan` on the diagonal (rows of connected nodes
///   sum to one), or `nil` if `gamma` is not positive.
public func NeighbourhoodWeights(graph: Graph, gamma: Double = 0.5) -> Matrix? {
    guard !gamma.isNaN, gamma > 0 else { return nil }

    let names = graph.nodes.map { $0.name }
    let K = names.count
    let A = weightedAdjacency(graph)

    let W = Matrix(K, K, 0.0)
    W.rowNames = names
    W.colNames = names

    for i in 0..<K {
        // R: adj <- A > 0; neighbours visited in ascending vertex order.
        let neighbours = (0..<K).filter { A[i][$0] > 0 }
        let k = neighbours.count
        if k > 0 {
            if gamma.isInfinite {
                for j in neighbours { W[i, j] = 1.0 / Double(k) }
            } else {
                let s = A[i].reduce(0, +)                                   // R: rowSums(A)
                let b = gamma * s / Double(k)
                let z = neighbours.map { A[i][$0] * A[i][$0] / (2.0 * b * b) }
                let zMin = z.min() ?? 0.0
                let v = z.map { exp(-($0 - zMin)) }
                let total = v.reduce(0, +)
                for (index, j) in neighbours.enumerated() { W[i, j] = v[index] / total }
            }
        }
        W[i, i] = .nan
    }
    return W
}

// MARK: - gravity_edges

/// One edge of ``GravityEdges(graph:gamma:x:)`` — mirrors a row of gstudio's
/// `gravity_edges()` table.
public struct GravityEdge: Sendable, Equatable {
    /// The edge's first endpoint (the upstream end when a covariate `x` is given).
    public let from: String
    /// The edge's second endpoint.
    public let to: String
    /// The edge weight (conditional genetic distance).
    public let weight: Double
    /// `w_{from|to}`: the weight `from` holds in `to`'s neighbourhood.
    public let wFrom: Double
    /// `w_{to|from}`: the weight `to` holds in `from`'s neighbourhood.
    public let wTo: Double
    /// The gravity asymmetry `Δ_{from→to} = w_{from|to} − w_{to|from}`;
    /// positive when `from` is the source.
    public let delta: Double
    /// The degree-only term `Δ⁰ = 1/k_to − 1/k_from`.
    public let delta0: Double
}

/// Per-edge neighbourhood weights and gravity asymmetry — a port of gstudio's
/// `gravity_edges()`.
///
/// `Δ_{i→j} = w_{i|j} − w_{j|i}` is the negative of
/// ``GraphAsymmetries(graph:bandwidth:scale:)``'s `delta` at the same
/// bandwidth (`scale = gamma`).
///
/// - Parameters:
///   - graph: An undirected, weighted graph.
///   - gamma: Bandwidth multiplier (default `0.5`); see
///     ``NeighbourhoodWeights(graph:gamma:)``.
///   - x: Optional covariate keyed by node name (e.g. position along a
///     hypothesized axis of flow). When given, each edge is oriented from the
///     lower to the higher value of `x`.
/// - Returns: One ``GravityEdge`` per undirected edge in
///   ``Graph/undirectedEdgeList()`` order, or `nil` if `gamma` is not positive
///   or `x` omits a node.
public func GravityEdges(graph: Graph, gamma: Double = 0.5, x: [String: Double]? = nil) -> [GravityEdge]? {
    guard let W = NeighbourhoodWeights(graph: graph, gamma: gamma) else { return nil }
    if let x, !graph.nodes.allSatisfy({ x[$0.name] != nil }) { return nil }

    let indexOf = Dictionary(uniqueKeysWithValues: graph.nodes.enumerated().map { ($1.name, $0) })
    let adjacency = graph.undirectedAdjacency()

    return graph.undirectedEdgeList().map { edge -> GravityEdge in
        var (from, to) = (edge.from, edge.to)
        if let x, x[from]! > x[to]! { swap(&from, &to) }               // R: flip <- x[from] > x[to]
        let f = indexOf[from]!, t = indexOf[to]!
        let wFrom = W[t, f]                                             // from's weight in to's neighbourhood
        let wTo = W[f, t]                                               // to's weight in from's neighbourhood
        let kFrom = Double(adjacency[from]?.count ?? 0)
        let kTo = Double(adjacency[to]?.count ?? 0)
        return GravityEdge(from: from, to: to, weight: edge.weight,
                           wFrom: wFrom, wTo: wTo, delta: wFrom - wTo,
                           delta0: 1.0 / kTo - 1.0 / kFrom)
    }
}

// MARK: - source_sink_scores

/// One population's row of ``SourceSinkScores(graph:gamma:x:)`` — mirrors a
/// row of gstudio's `source_sink_scores()` table.
public struct SourceSinkScore: Sendable, Equatable {
    /// The population (node name).
    public let stratum: String
    /// Source-sink score `S`: the least-squares solution of `Sᵢ − Sⱼ ≈ Δ_{i→j}`
    /// over all edges, centred within the node's connected component. Higher =
    /// more of a source; `0` for an isolated node.
    public let s: Double
    /// Gravity `gᵢ = Σⱼ w_{i|j}`: the node's total weight across its
    /// neighbours' neighbourhoods.
    public let gravity: Double
    /// Source-sink balance `gᵢ − 1 = Σⱼ Δ_{i→j}`.
    public let balance: Double
    /// Degree `kᵢ`.
    public let degree: Int
    /// Connected-component id (1-based, numbered in node order, as igraph's
    /// `components()$membership`).
    public let component: Int
    /// Degree-only score `S⁰ = −1/k`, centred within the component; `.nan` for
    /// an isolated node.
    public let s0: Double
    /// Orientation imbalance: edges on which the node is upstream minus edges on
    /// which it is downstream. `nil` when no covariate `x` was given.
    public let n: Double?
}

/// The split of the axis-oriented sum `|E|·Δ̄ = Σ Δ_{i→j}` into the part
/// reproduced by `S` (`Σᵢ Sᵢ nᵢ`) and the non-directional residual — gstudio's
/// `attr(, "dbar_decomposition")`.
public struct DeltaBarDecomposition: Sendable, Equatable {
    /// `Σ Δ_{i→j}` over all edges, oriented by `x`.
    public let sumDelta: Double
    /// `Σᵢ Sᵢ nᵢ`.
    public let reproduced: Double
    /// `sumDelta − reproduced`.
    public let residual: Double
}

/// The result of ``SourceSinkScores(graph:gamma:x:)``: per-population scores
/// plus the degree diagnostics gstudio attaches as attributes. Report
/// `degreeShare` with any directional analysis.
public struct SourceSinkResult: Sendable {
    /// One row per node, in node order.
    public let scores: [SourceSinkScore]
    /// `R²` of `Δ` on the degree-only term `Δ⁰` (`degree_share`); `.nan` if
    /// either has no variance.
    public let degreeShare: Double
    /// `cor(S, S⁰)` over connected nodes (`cor_S_S0`); `.nan` if undefined.
    public let corSS0: Double
    /// `cor(S, degree)` over connected nodes (`cor_S_degree`); `.nan` if undefined.
    public let corSDegree: Double
    /// Share of `Σ Δ²` reproduced by `Sᵢ − Sⱼ` (`gradient_share`); `1` on a tree.
    public let gradientShare: Double
    /// The bandwidth multiplier used.
    public let gamma: Double
    /// Present only when a covariate `x` was given.
    public let deltaBarDecomposition: DeltaBarDecomposition?
}

/// Gravity, source-sink balance, and source-sink score for every population —
/// a port of gstudio's `source_sink_scores()`.
///
/// `S` is the least-squares solution of `Sᵢ − Sⱼ ≈ Δ_{i→j}` over all edges
/// (the Moore-Penrose solution of the graph Laplacian system `L S = balance`,
/// via `MoorePenroseInverse(_:tol:)`, as R's `MASS::ginv`), centred within
/// each connected component.
///
/// - Parameters:
///   - graph: An undirected, weighted graph.
///   - gamma: Bandwidth multiplier (default `0.5`); see
///     ``NeighbourhoodWeights(graph:gamma:)``.
///   - x: Optional covariate keyed by node name. When given, edges are oriented
///     by `x` and each node's orientation imbalance `n` and the
///     ``DeltaBarDecomposition`` are returned.
/// - Returns: The scores and diagnostics, or `nil` if `gamma` is not positive
///   or `x` omits a node.
public func SourceSinkScores(graph: Graph, gamma: Double = 0.5, x: [String: Double]? = nil) -> SourceSinkResult? {
    guard let edges = GravityEdges(graph: graph, gamma: gamma, x: x) else { return nil }

    let names = graph.nodes.map { $0.name }
    let K = names.count
    let indexOf = Dictionary(uniqueKeysWithValues: names.enumerated().map { ($1, $0) })
    let fromIndex = edges.map { indexOf[$0.from]! }
    let toIndex = edges.map { indexOf[$0.to]! }

    // Incidence B (+1 at from, −1 at to). balance = Bᵀ Δ; gravity sums w_from
    // by `from` then w_to by `to` (R's tapply over c(w_from, w_to)).
    var balance = [Double](repeating: 0, count: K)
    var gravity = [Double](repeating: 0, count: K)
    var orientation = [Double](repeating: 0, count: K)
    var laplacian = [[Double]](repeating: [Double](repeating: 0, count: K), count: K)
    for (e, edge) in edges.enumerated() {
        let f = fromIndex[e], t = toIndex[e]
        balance[f] += edge.delta
        balance[t] -= edge.delta
        orientation[f] += 1
        orientation[t] -= 1
        laplacian[f][f] += 1; laplacian[t][t] += 1                      // L = BᵀB
        laplacian[f][t] -= 1; laplacian[t][f] -= 1
    }
    for (e, edge) in edges.enumerated() { gravity[fromIndex[e]] += edge.wFrom }
    for (e, edge) in edges.enumerated() { gravity[toIndex[e]] += edge.wTo }
    let degree = (0..<K).map { Int(laplacian[$0][$0]) }

    let component = connectedComponents(graph, names: names, indexOf: indexOf)

    // S: per component, ginv(L[m, m]) %*% balance[m], then centred.
    var S = [Double](repeating: 0, count: K)
    for c in Set(component) {
        let members = (0..<K).filter { component[$0] == c }
        guard members.count > 1 else { continue }
        let Lm = Matrix(members.count, members.count, 0.0)
        for (r, i) in members.enumerated() {
            for (col, j) in members.enumerated() { Lm[r, col] = laplacian[i][j] }
        }
        let Linv = MoorePenroseInverse(Lm)
        var v = [Double](repeating: 0, count: members.count)
        for r in 0..<members.count {
            var acc = 0.0
            for (col, j) in members.enumerated() { acc += Linv[r, col] * balance[j] }
            v[r] = acc
        }
        let mean = v.reduce(0, +) / Double(v.count)
        for (r, i) in members.enumerated() { S[i] = v[r] - mean }
    }

    // S0 = −1/k (NA for isolates), centred within component ignoring NA.
    var S0 = degree.map { $0 > 0 ? -1.0 / Double($0) : Double.nan }
    var componentMean: [Int: Double] = [:]
    for c in Set(component) {
        let values = (0..<K).filter { component[$0] == c && !S0[$0].isNaN }.map { S0[$0] }
        componentMean[c] = values.isEmpty ? .nan : values.reduce(0, +) / Double(values.count)
    }
    for i in 0..<K { S0[i] -= componentMean[component[i]]! }

    // Diagnostics.
    let delta = edges.map { $0.delta }
    let delta0 = edges.map { $0.delta0 }
    let connected = (0..<K).filter { degree[$0] > 0 }
    let sConnected = connected.map { S[$0] }
    func varies(_ v: [Double]) -> Bool { v.count > 1 && sampleSD(v) > 0 }

    let degreeShare = varies(delta) && varies(delta0) ? pow(pearsonCorrelation(delta, delta0), 2) : .nan
    let s0Connected = connected.map { S0[$0] }
    let corSS0 = varies(sConnected) && varies(s0Connected) ? pearsonCorrelation(sConnected, s0Connected) : .nan
    let kConnected = connected.map { Double(degree[$0]) }
    let corSDegree = varies(sConnected) && varies(kConnected) ? pearsonCorrelation(sConnected, kConnected) : .nan
    let fit = edges.indices.map { S[fromIndex[$0]] - S[toIndex[$0]] }
    let sumDeltaSquared = delta.reduce(0) { $0 + $1 * $1 }
    let gradientShare = sumDeltaSquared > 0 ? fit.reduce(0) { $0 + $1 * $1 } / sumDeltaSquared : .nan

    var decomposition: DeltaBarDecomposition?
    if x != nil {
        let sumDelta = delta.reduce(0, +)
        let reproduced = (0..<K).reduce(0.0) { $0 + S[$1] * orientation[$1] }
        decomposition = DeltaBarDecomposition(sumDelta: sumDelta, reproduced: reproduced,
                                              residual: sumDelta - reproduced)
    }

    let scores = (0..<K).map { i in
        SourceSinkScore(stratum: names[i], s: S[i], gravity: gravity[i], balance: balance[i],
                        degree: degree[i], component: component[i], s0: S0[i],
                        n: x == nil ? nil : orientation[i])
    }
    return SourceSinkResult(scores: scores, degreeShare: degreeShare, corSS0: corSS0,
                            corSDegree: corSDegree, gradientShare: gradientShare,
                            gamma: gamma, deltaBarDecomposition: decomposition)
}

// MARK: - pgd

/// The directed graph of partitioned conditional genetic distance — a port of
/// gstudio's `pgd(graph, output = "graph")`.
///
/// Each undirected edge `(u, v)` with conditional genetic distance `e` is split
/// into two arcs by the neighbourhood weights `w_{v|u}` and `w_{u|v}`:
/// `u → v` carries `e · w_{v|u} / (w_{v|u} + w_{u|v})` and `v → u` the
/// remainder (an even split if both weights are zero), so the two arcs sum to
/// `e`. Arcs are shorter in the direction of gene flow.
///
/// - Parameters:
///   - graph: An undirected, weighted graph.
///   - gamma: Bandwidth multiplier (default `0.5`); see
///     ``NeighbourhoodWeights(graph:gamma:)``.
/// - Returns: A directed graph with every original node (same order and
///   attributes) and two arcs per edge — all forward arcs, then all reverse
///   arcs — or `nil` if `gamma` is not positive.
public func PartitionedGeneticDistanceGraph(graph: Graph, gamma: Double = 0.5) -> Graph? {
    guard let arcs = partitionedArcs(graph, gamma: gamma) else { return nil }
    let newNodes = graph.nodes.map { source -> Node in
        let copy = Node(name: source.name, size: source.size, color: source.color,
                        categoricalAttributes: source.categoricalAttributes,
                        continuousAttributes: source.continuousAttributes)
        if let coordinate = source.coordinate { copy.coordinate = coordinate }
        return copy
    }
    let edges = arcs.map { Edge(fromNode: newNodes[$0.from], toNode: newNodes[$0.to], weight: $0.weight) }
    return Graph(nodes: newNodes, edges: edges)
}

/// All-pairs directed partitioned conditional genetic distance — a port of
/// gstudio's `pgd(graph, output = "matrix")` / `genetic_distance(mode = "pgd")`.
///
/// Shortest-path distances over ``PartitionedGeneticDistanceGraph(graph:gamma:)``.
/// The result is asymmetric: `[i, j]` is the distance from `i` to `j`, shorter
/// in the direction of gene flow.
///
/// - Parameters:
///   - graph: An undirected, weighted graph.
///   - gamma: Bandwidth multiplier (default `0.5`).
/// - Returns: A `K × K` matrix in node order with node row/column names, `0` on
///   the diagonal and `.infinity` for unreachable pairs, or `nil` if `gamma` is
///   not positive.
public func PartitionedGeneticDistance(graph: Graph, gamma: Double = 0.5) -> Matrix? {
    guard let arcs = partitionedArcs(graph, gamma: gamma) else { return nil }
    let names = graph.nodes.map { $0.name }
    let K = names.count

    var outgoing = [[(to: Int, weight: Double)]](repeating: [], count: K)
    for arc in arcs { outgoing[arc.from].append((arc.to, arc.weight)) }

    let D = Matrix(K, K, Double.infinity)
    D.rowNames = names
    D.colNames = names
    for source in 0..<K {
        // Dijkstra from `source` (K is a handful of populations; O(K²) is fine).
        var distance = [Double](repeating: .infinity, count: K)
        var done = [Bool](repeating: false, count: K)
        distance[source] = 0
        while let u = (0..<K).filter({ !done[$0] && distance[$0].isFinite })
                .min(by: { distance[$0] < distance[$1] }) {
            done[u] = true
            for (v, w) in outgoing[u] where distance[u] + w < distance[v] {
                distance[v] = distance[u] + w
            }
        }
        for target in 0..<K { D[source, target] = distance[target] }
    }
    return D
}

// MARK: - Internals

/// The partitioned arcs (node indices) of `pgd()`: forward arcs for every edge
/// in ``Graph/undirectedEdgeList()`` order, then the reverse arcs.
private func partitionedArcs(_ graph: Graph, gamma: Double) -> [(from: Int, to: Int, weight: Double)]? {
    guard let W = NeighbourhoodWeights(graph: graph, gamma: gamma) else { return nil }
    let indexOf = Dictionary(uniqueKeysWithValues: graph.nodes.enumerated().map { ($1.name, $0) })
    let edges = graph.undirectedEdgeList()

    var forward: [(Int, Int, Double)] = []
    var reverse: [(Int, Int, Double)] = []
    for edge in edges {
        let u = indexOf[edge.from]!, v = indexOf[edge.to]!
        let wa = W[u, v], wt = W[v, u]                                  // w_{v|u}, w_{u|v}
        let fraction = wa + wt > 0 ? wa / (wa + wt) : 0.5
        forward.append((u, v, edge.weight * fraction))
        reverse.append((v, u, edge.weight * (1.0 - fraction)))
    }
    return (forward + reverse).map { (from: $0.0, to: $0.1, weight: $0.2) }
}

/// Dense symmetric weighted adjacency in node order (R's
/// `as_adjacency_matrix(graph, attr = "weight")` for an undirected simple graph).
private func weightedAdjacency(_ graph: Graph) -> [[Double]] {
    let K = graph.nodes.count
    let indexOf = Dictionary(uniqueKeysWithValues: graph.nodes.enumerated().map { ($1.name, $0) })
    var A = [[Double]](repeating: [Double](repeating: 0, count: K), count: K)
    for edge in graph.undirectedEdgeList() {
        guard let i = indexOf[edge.from], let j = indexOf[edge.to] else { continue }
        A[i][j] = edge.weight
        A[j][i] = edge.weight
    }
    return A
}

/// Connected-component membership (1-based), numbered by the lowest node index
/// in each component — igraph's `components()$membership`.
private func connectedComponents(_ graph: Graph, names: [String], indexOf: [String: Int]) -> [Int] {
    let adjacency = graph.undirectedAdjacency()
    var membership = [Int](repeating: 0, count: names.count)
    var next = 0
    for start in names.indices where membership[start] == 0 {
        next += 1
        membership[start] = next
        var stack = [start]
        while let u = stack.popLast() {
            for neighbour in adjacency[names[u]]?.keys ?? [:].keys {
                let v = indexOf[neighbour]!
                if membership[v] == 0 {
                    membership[v] = next
                    stack.append(v)
                }
            }
        }
    }
    return membership
}

/// Sample standard deviation (R's `sd()`).
private func sampleSD(_ v: [Double]) -> Double {
    let mean = v.reduce(0, +) / Double(v.count)
    return (v.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(v.count - 1)).squareRoot()
}
