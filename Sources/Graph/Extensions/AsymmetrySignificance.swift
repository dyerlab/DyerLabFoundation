//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AsymmetrySignificance.swift
//  Graph
//
//  Ports of the graph-only members of gstudio's (>= 1.15) `asymmetry_significance()`
//  family: the bandwidth-alignment permutation null (`asymmetry_bandwidth()`,
//  mode "mechanism") and the network rewiring null (`asymmetry_network()`, mode
//  "existence"). Both run through ``RMersenneTwister``: the bandwidth null is
//  identical to R's for a matching seed; the network null is statistically
//  equivalent (its `.degree` rewiring is a functional, not RNG-exact, port of
//  igraph's edge-swap chain — see ``RandomizeGraph(graph:mode:seed:)``).
//
//  The genotype-driven members (`asymmetry_permutation()` — mode "location" —,
//  `asymmetry_ci()`, `permute_popgraph()`) re-estimate the population graph from
//  raw genotypes and live in PopulationGenetics.
//
//  Created by Rodney Dyer on 2026.09.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import Foundation

/// One row of a per-edge asymmetry-significance table — mirrors the
/// `data.frame` returned by gstudio's `asymmetry_bandwidth()` /
/// `asymmetry_permutation()` (`from`, `to`, `delta`, `statistic`, `p.value`).
public struct EdgeAsymmetrySignificance: Sendable, Equatable {
    /// Edge's first endpoint (``Graph/undirectedEdgeList()`` order).
    public let from: String
    /// Edge's second endpoint.
    public let to: String
    /// Observed asymmetry index `Δ` for this edge.
    public let delta: Double
    /// The test statistic: `Δ` itself for the bandwidth null; the deviation from
    /// the edge's permutation-null mean, `Δ − mean(null)`, for the
    /// fixed-topology label permutation.
    public let statistic: Double
    /// Add-one permutation p-value `(1 + #{null as extreme}) / (1 + B)`
    /// (Phipson & Smyth 2010), with `B` the number of valid null draws.
    public let pValue: Double
    /// The edge's null distribution (valid draws only), when requested with
    /// `returnNull: true` — gstudio's `attr(, "null_distribution")` row.
    public let nullDistribution: [Double]?

    /// Initializes a new per-edge asymmetry-significance row.
    ///
    /// - Parameters:
    ///   - from: The edge's first endpoint.
    ///   - to: The edge's second endpoint.
    ///   - delta: Observed asymmetry index `Δ`.
    ///   - statistic: The test statistic.
    ///   - pValue: Add-one permutation p-value.
    ///   - nullDistribution: The edge's null distribution, or `nil` if not kept.
    public init(from: String, to: String, delta: Double, statistic: Double,
                pValue: Double, nullDistribution: [Double]? = nil) {
        self.from = from
        self.to = to
        self.delta = delta
        self.statistic = statistic
        self.pValue = pValue
        self.nullDistribution = nullDistribution
    }
}

/// The graph-level result of ``AsymmetryNetworkTest(graph:permutations:rewire:returnNull:seed:)``
/// — the fields of the `htest` gstudio's `asymmetry_network()` returns.
public struct AsymmetryNetworkResult: Sendable, Equatable {
    /// Observed mean `|Δ|` over all edges (`statistic`).
    public let statistic: Double
    /// Add-one permutation p-value against the rewiring null (one-sided,
    /// `alternative = "greater"`).
    public let pValue: Double
    /// Number of edges in the observed graph (`parameter["edges"]`).
    public let edgeCount: Int
    /// Number of valid rewired graphs in the null, `B` (`parameter["nperm"]`).
    public let validPermutations: Int
    /// Mean of the null distribution (`estimate`).
    public let nullMean: Double
    /// The null distribution of mean `|Δ|`, when requested with `returnNull: true`.
    public let nullDistribution: [Double]?
}

/// Bandwidth-alignment permutation null for edge asymmetry — a port of
/// gstudio's `asymmetry_bandwidth()` (`asymmetry_significance(mode = "mechanism")`).
///
/// Holds the graph topology and edge weights fixed and permutes the per-node
/// kernel bandwidths across nodes, recomputing every edge's `Δ` each time. Tests
/// whether the specific pairing of source- and sink-like bandwidths on an edge
/// is non-random.
///
/// - Parameters:
///   - graph: An undirected, weighted graph.
///   - permutations: Number of bandwidth permutations (default `999`).
///   - returnNull: Keep each edge's null distribution on its row (default `false`).
///   - seed: RNG seed, equivalent to R's `set.seed(seed)`.
/// - Returns: One row per undirected edge (``Graph/undirectedEdgeList()``
///   order), or `nil` if ``GraphAsymmetries(graph:bandwidth:scale:)`` cannot be
///   computed for `graph`.
public func AsymmetryBandwidthTest(graph: Graph,
                                   permutations: Int = 999,
                                   returnNull: Bool = false,
                                   seed: Int) -> [EdgeAsymmetrySignificance]? {
    guard let observed = GraphAsymmetries(graph: graph) else { return nil }

    let nodeNames = graph.nodes.map { $0.name }
    let observedBandwidths = nodeNames.map { observed.bandwidth[$0] ?? .nan }
    let observedDelta = observed.edges.map { $0.delta }
    let edgeList = graph.undirectedEdgeList()
    let adjacency = graph.undirectedAdjacency()

    var nulls = [[Double]](repeating: [], count: observedDelta.count)
    var rng = RMersenneTwister(seed: seed)

    for _ in 0..<permutations {
        let permuted = rng.sample(observedBandwidths)                 // R: sample(b_obs)
        let bandwidth = Dictionary(uniqueKeysWithValues: zip(nodeNames, permuted))
        let nullDelta = directionalEdges(of: graph, bandwidth: bandwidth, adjacency: adjacency).map { $0.delta }
        for i in nullDelta.indices where !nullDelta[i].isNaN {
            nulls[i].append(nullDelta[i])
        }
    }

    return edgeList.indices.map { i in
        let exceedances = nulls[i].filter { abs($0) >= abs(observedDelta[i]) }.count
        return EdgeAsymmetrySignificance(
            from: edgeList[i].from, to: edgeList[i].to,
            delta: observedDelta[i], statistic: observedDelta[i],
            pValue: (1.0 + Double(exceedances)) / (1.0 + Double(nulls[i].count)),
            nullDistribution: returnNull ? nulls[i] : nil)
    }
}

/// Network (rewiring) null for graph asymmetry — a port of gstudio's
/// `asymmetry_network()` (`asymmetry_significance(mode = "existence")`).
///
/// Rewires the graph `permutations` times (via
/// ``RandomizeGraph(graph:mode:seed:)``), reassigns the observed edge-weight
/// multiset to the rewired edges, and rebuilds a null distribution of the
/// graph-level statistic mean `|Δ|`. Tests whether the overall amount of
/// directional asymmetry is unusual for a graph of this size/degree sequence.
///
/// - Parameters:
///   - graph: An undirected, weighted graph.
///   - permutations: Number of rewired graphs (default `999`).
///   - rewire: `.degree` (default) or `.full`, passed to the randomiser.
///   - returnNull: Keep the null distribution on the result (default `false`).
///   - seed: RNG seed. `.full` rewiring consumes it exactly as R does; `.degree`
///     rewiring is statistically, not draw-for-draw, equivalent to R.
/// - Returns: The graph-level test, or `nil` if the observed graph's
///   asymmetries cannot be computed or no rewired graph yields a valid
///   statistic (gstudio stops in both cases). Rewired graphs with isolated
///   nodes (possible under `.full`) are dropped from the null, as in R.
public func AsymmetryNetworkTest(graph: Graph,
                                 permutations: Int = 999,
                                 rewire: GraphRandomization = .degree,
                                 returnNull: Bool = false,
                                 seed: Int) -> AsymmetryNetworkResult? {
    guard let observed = GraphAsymmetries(graph: graph) else { return nil }

    let observedStat = mean(observed.edges.map { abs($0.delta) })
    let weights = graph.undirectedEdgeList().map { $0.weight }        // R: E(graph)$weight

    var nullValues: [Double] = []
    var rng = RMersenneTwister(seed: seed)

    for _ in 0..<permutations {
        guard let rewired = randomizeGraph(graph, mode: rewire, using: &rng) else { continue }

        let edgeCount = rewired.edges.count
        let sampledWeights = rng.sample(weights, size: edgeCount, replace: weights.count != edgeCount)
        for (index, edge) in rewired.edges.enumerated() {
            edge.weight = sampledWeights[index]
        }

        // R records a rewired graph with an isolated node as NA.
        let hasIsolate = rewired.nodes.contains { rewired.undirectedDegree(of: $0.name) == 0 }
        guard !hasIsolate, let asym = GraphAsymmetries(graph: rewired) else { continue }
        nullValues.append(mean(asym.edges.map { abs($0.delta) }))
    }

    guard !nullValues.isEmpty else { return nil }

    let exceedances = nullValues.filter { $0 >= observedStat }.count
    let pValue = (1.0 + Double(exceedances)) / (1.0 + Double(nullValues.count))

    return AsymmetryNetworkResult(statistic: observedStat, pValue: pValue,
                                  edgeCount: observed.edges.count,
                                  validPermutations: nullValues.count,
                                  nullMean: mean(nullValues),
                                  nullDistribution: returnNull ? nullValues : nil)
}

// MARK: - Dispatcher

/// Which hypothesis ``AsymmetrySignificance(graph:mode:permutations:rewire:pendants:returnNull:seed:)``
/// tests — the graph-only modes of gstudio's `asymmetry_significance()`. The
/// third mode, `"location"` (fixed-topology label permutation), re-estimates the
/// population graph from genotypes and lives in PopulationGenetics as
/// `AsymmetryPermutationTest`.
public enum AsymmetryNull: Sendable {
    /// `"existence"` — `asymmetry_network()`: is there more overall asymmetry
    /// than in rewired graphs with this degree sequence?
    case existence
    /// `"mechanism"` — `asymmetry_bandwidth()`: is each edge's asymmetry
    /// explained by the pairing of its endpoints' bandwidths?
    case mechanism
}

/// How to treat edges incident to a degree-one (pendant / leaf) node, whose
/// direction is topologically forced and whose asymmetry is therefore inflated.
public enum PendantHandling: Sendable {
    /// Keep them, but report the count in `pendantEdgeCount` (gstudio's default
    /// `"warn"`, minus the R `warning()`).
    case warn
    /// Keep them and say nothing.
    case keep
    /// Drop them from the result.
    case drop
}

/// The result of ``AsymmetrySignificance(graph:mode:permutations:rewire:pendants:returnNull:seed:)``.
public enum AsymmetrySignificanceResult: Sendable {
    /// `.existence`: a single graph-level test.
    case existence(AsymmetryNetworkResult)
    /// `.mechanism`: one row per retained edge, plus the number of
    /// pendant-incident edges dropped (`.drop`) or flagged (`.warn`) — `nil`
    /// when there are none or with `.keep`.
    case edges([EdgeAsymmetrySignificance], pendantEdgeCount: Int?)
}

/// The graph-only members of gstudio's `asymmetry_significance()` dispatcher —
/// `mode = "existence"` and `mode = "mechanism"` — with the same post-hoc
/// pendant-edge handling.
///
/// - Parameters:
///   - graph: An undirected, weighted graph.
///   - mode: `.existence` or `.mechanism`.
///   - permutations: Resampling iterations (default `999`).
///   - rewire: Randomisation mode for `.existence` (default `.degree`); ignored
///     for `.mechanism`.
///   - pendants: Leaf-edge handling for `.mechanism` (default `.warn`); ignored
///     for `.existence`.
///   - returnNull: Keep the null distribution(s) on the result (default `false`).
///   - seed: RNG seed, equivalent to R's `set.seed(seed)`.
/// - Returns: The `.existence` graph-level test or the `.mechanism` per-edge rows, or `nil` if the
///   underlying test can't be computed for this graph.
public func AsymmetrySignificance(graph: Graph,
                                  mode: AsymmetryNull,
                                  permutations: Int = 999,
                                  rewire: GraphRandomization = .degree,
                                  pendants: PendantHandling = .warn,
                                  returnNull: Bool = false,
                                  seed: Int) -> AsymmetrySignificanceResult? {
    switch mode {
    case .existence:
        guard let result = AsymmetryNetworkTest(graph: graph, permutations: permutations,
                                                rewire: rewire, returnNull: returnNull,
                                                seed: seed) else { return nil }
        return .existence(result)

    case .mechanism:
        guard let rows = AsymmetryBandwidthTest(graph: graph, permutations: permutations,
                                                returnNull: returnNull, seed: seed) else { return nil }
        let (kept, count) = handlePendantEdges(rows, graph: graph, pendants: pendants,
                                               endpoints: { ($0.from, $0.to) })
        return .edges(kept, pendantEdgeCount: count)
    }
}

/// gstudio's `.handle_pendant_edges()`: flag (`.warn`) or drop (`.drop`) rows
/// whose edge touches a degree-≤1 node. Returns the retained rows and the
/// pendant count (`nil` when there are none, or for `.keep`).
///
/// - Parameters:
///   - rows: Per-edge results.
///   - graph: The graph the rows describe.
///   - pendants: How to handle leaf edges.
///   - endpoints: Extracts a row's two endpoint names.
public func handlePendantEdges<Row>(_ rows: [Row],
                                    graph: Graph,
                                    pendants: PendantHandling,
                                    endpoints: (Row) -> (String, String)) -> ([Row], Int?) {
    guard pendants != .keep else { return (rows, nil) }
    let leaves = Set(graph.nodes.map { $0.name }.filter { graph.undirectedDegree(of: $0) <= 1 })
    func isPendant(_ row: Row) -> Bool {
        let (from, to) = endpoints(row)
        return leaves.contains(from) || leaves.contains(to)
    }
    let pendantCount = rows.filter(isPendant).count
    guard pendantCount > 0 else { return (rows, nil) }
    return (pendants == .drop ? rows.filter { !isPendant($0) } : rows, pendantCount)
}

private func mean(_ values: [Double]) -> Double {
    values.isEmpty ? .nan : values.reduce(0, +) / Double(values.count)
}
