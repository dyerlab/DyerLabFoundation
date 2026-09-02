//
//  AsymmetrySignificance.swift
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
//  Ports of the graph-only members of gstudio's `asymmetry_significance()`
//  family: the bandwidth-alignment permutation null (`asymmetry_bandwidth()`)
//  and the network (rewiring) null (`asymmetry_network()`). Both run through
//  ``RMersenneTwister``, so with a matching seed and input graph the null
//  distribution is identical to R's `set.seed(seed); asymmetry_*(graph, ...)`.
//
//  The genotype-driven members (`asymmetry_permutation`, `asymmetry_jackknife`,
//  `permute_popgraph`) re-estimate the population graph from raw genotypes and
//  live in PopulationGenetics.
//

import Matrix
import Foundation

/// One row of an asymmetry-significance table — mirrors the `data.frame`
/// returned by gstudio's `asymmetry_*` functions.
public struct EdgeAsymmetrySignificance: Sendable, Equatable {
    /// Edge's first endpoint, or `nil` for a graph-level row (network null).
    public let from: String?
    /// Edge's second endpoint, or `nil` for a graph-level row.
    public let to: String?
    /// Observed asymmetry: per-edge `Δ` for the edge nulls, mean `|Δ|` for the
    /// network null.
    public let delta: Double
    /// The test statistic (equal to `delta` for these two modes).
    public let statistic: Double
    /// Add-one permutation p-value `(1 + #{null ≥ observed}) / (1 + B)`
    /// (Phipson & Smyth 2010).
    public let pValue: Double
    /// Lower CI bound — always `nil` for permutation nulls.
    public let ciLow: Double?
    /// Upper CI bound — always `nil` for permutation nulls.
    public let ciHigh: Double?
}

/// Bandwidth-alignment permutation null for edge asymmetry — a port of
/// gstudio's `asymmetry_bandwidth()`.
///
/// Holds the graph topology and edge weights fixed and permutes the per-node
/// kernel bandwidths across nodes, recomputing every edge's `Δ` each time. Tests
/// whether the specific pairing of source- and sink-like bandwidths on an edge
/// is non-random.
///
/// - Parameters:
///   - graph: An undirected, weighted graph.
///   - permutations: Number of bandwidth permutations (default `999`).
///   - seed: RNG seed, equivalent to R's `set.seed(seed)`.
/// - Returns: One row per undirected edge (``Graph/undirectedEdgeList()``
///   order), or `nil` if ``GraphAsymmetries(graph:bandwidth:scale:)`` cannot be
///   computed for `graph`.
public func AsymmetryBandwidthTest(graph: Graph,
                                   permutations: Int = 999,
                                   seed: Int) -> [EdgeAsymmetrySignificance]? {
    guard let observed = GraphAsymmetries(graph: graph) else { return nil }

    let nodeNames = graph.nodes.map { $0.name }
    let observedBandwidths = nodeNames.map { observed.bandwidth[$0] ?? .nan }
    let observedDelta = observed.edges.map { $0.delta }
    let edgeList = graph.undirectedEdgeList()
    let adjacency = graph.undirectedAdjacency()

    var greaterOrEqual = [Int](repeating: 0, count: observedDelta.count)
    var rng = RMersenneTwister(seed: seed)

    for _ in 0..<permutations {
        let permuted = rng.sample(observedBandwidths)                 // R: sample(b_obs)
        let bandwidth = Dictionary(uniqueKeysWithValues: zip(nodeNames, permuted))
        let nullDelta = directionalEdges(of: graph, bandwidth: bandwidth, adjacency: adjacency).map { $0.delta }
        for i in nullDelta.indices where abs(nullDelta[i]) >= abs(observedDelta[i]) {
            greaterOrEqual[i] += 1
        }
    }

    let denominator = 1.0 + Double(permutations)
    return edgeList.indices.map { i in
        EdgeAsymmetrySignificance(
            from: edgeList[i].from, to: edgeList[i].to,
            delta: observedDelta[i], statistic: observedDelta[i],
            pValue: (1.0 + Double(greaterOrEqual[i])) / denominator,
            ciLow: nil, ciHigh: nil)
    }
}

/// Network (rewiring) null for graph asymmetry — a port of gstudio's
/// `asymmetry_network()`.
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
///   - seed: RNG seed, equivalent to R's `set.seed(seed)`.
/// - Returns: A single graph-level row (`from`/`to` are `nil`), or `nil` if the
///   observed graph's asymmetries cannot be computed.
///
/// - Note: With `rewire: .full` a rewired graph can have an isolated node, on
///   which asymmetries are undefined; gstudio errors there, this skips that
///   draw. `.degree` (the default) preserves every node's degree and never hits
///   this.
public func AsymmetryNetworkTest(graph: Graph,
                                 permutations: Int = 999,
                                 rewire: GraphRandomization = .degree,
                                 seed: Int) -> EdgeAsymmetrySignificance? {
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

        guard let asym = GraphAsymmetries(graph: rewired) else { continue }
        nullValues.append(mean(asym.edges.map { abs($0.delta) }))
    }

    let exceedances = nullValues.filter { $0 >= observedStat }.count
    let pValue = (1.0 + Double(exceedances)) / (1.0 + Double(nullValues.count))

    return EdgeAsymmetrySignificance(from: nil, to: nil,
                                     delta: observedStat, statistic: observedStat,
                                     pValue: pValue, ciLow: nil, ciHigh: nil)
}

// MARK: - Dispatcher

/// Which resampling null ``AsymmetrySignificance(graph:mode:permutations:rewire:pendants:seed:)``
/// evaluates. The two genotype-driven modes of gstudio's
/// `asymmetry_significance()` (`"permutation"`, `"jackknife"`) re-estimate the
/// population graph and live in PopulationGenetics.
public enum AsymmetryNull: Sendable {
    /// `asymmetry_bandwidth()` — permute node bandwidths.
    case bandwidth
    /// `asymmetry_network()` — rewire the graph.
    case network
}

/// How to treat edges incident to a degree-one (pendant / leaf) node, whose
/// direction is topologically forced and whose asymmetry is therefore inflated.
public enum PendantHandling: Sendable {
    /// Keep them, but report the count in
    /// ``AsymmetrySignificanceResult/pendantEdgeCount`` (gstudio's default
    /// `"warn"`, minus the R `warning()`).
    case warn
    /// Keep them and say nothing.
    case keep
    /// Drop them from the result.
    case drop
}

/// The result of ``AsymmetrySignificance(graph:mode:permutations:rewire:pendants:seed:)``.
public struct AsymmetrySignificanceResult: Sendable {
    /// One row per retained edge (`.bandwidth`) or a single graph-level row
    /// (`.network`).
    public let rows: [EdgeAsymmetrySignificance]
    /// The null that was evaluated.
    public let mode: AsymmetryNull
    /// Number of pendant-incident edges — dropped (`.drop`) or merely flagged
    /// (`.warn`). `nil` for `.network` and when there are none.
    public let pendantEdgeCount: Int?
}

/// The graph-only members of gstudio's `asymmetry_significance()` dispatcher —
/// `mode = "bandwidth"` and `mode = "network"` — with the same post-hoc
/// pendant-edge handling.
///
/// - Parameters:
///   - graph: An undirected, weighted graph.
///   - mode: `.bandwidth` or `.network`.
///   - permutations: Resampling iterations (default `999`).
///   - rewire: Randomisation mode for `.network` (default `.degree`); ignored
///     for `.bandwidth`.
///   - pendants: Leaf-edge handling for `.bandwidth` (default `.warn`); ignored
///     for `.network`.
///   - seed: RNG seed, equivalent to R's `set.seed(seed)`.
public func AsymmetrySignificance(graph: Graph,
                                  mode: AsymmetryNull,
                                  permutations: Int = 999,
                                  rewire: GraphRandomization = .degree,
                                  pendants: PendantHandling = .warn,
                                  seed: Int) -> AsymmetrySignificanceResult? {
    switch mode {
    case .network:
        guard let row = AsymmetryNetworkTest(graph: graph, permutations: permutations,
                                             rewire: rewire, seed: seed) else { return nil }
        return AsymmetrySignificanceResult(rows: [row], mode: .network, pendantEdgeCount: nil)

    case .bandwidth:
        guard let rows = AsymmetryBandwidthTest(graph: graph, permutations: permutations,
                                                seed: seed) else { return nil }
        guard pendants != .keep else {
            return AsymmetrySignificanceResult(rows: rows, mode: .bandwidth, pendantEdgeCount: nil)
        }

        let leaves = Set(graph.nodes.map { $0.name }.filter { graph.undirectedDegree(of: $0) <= 1 })
        let isPendant: (EdgeAsymmetrySignificance) -> Bool = { edge in
            (edge.from.map(leaves.contains) ?? false) || (edge.to.map(leaves.contains) ?? false)
        }
        let pendantCount = rows.filter(isPendant).count
        guard pendantCount > 0 else {
            return AsymmetrySignificanceResult(rows: rows, mode: .bandwidth, pendantEdgeCount: nil)
        }
        let kept = pendants == .drop ? rows.filter { !isPendant($0) } : rows
        return AsymmetrySignificanceResult(rows: kept, mode: .bandwidth, pendantEdgeCount: pendantCount)
    }
}

private func mean(_ values: [Double]) -> Double {
    values.isEmpty ? .nan : values.reduce(0, +) / Double(values.count)
}
