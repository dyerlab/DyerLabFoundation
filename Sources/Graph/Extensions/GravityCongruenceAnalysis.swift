//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GravityCongruenceAnalysis.swift
//  Graph
//
//  A port of gstudio 1.15.5's gravity_congruence(): do two Population Graphs
//  over the same populations (two species, markers or censuses) move genes
//  the same way? Each graph's genetic gravity is computed on its own topology
//  (`SourceSinkScores`, `GravityEdges`) and compared at two levels:
//
//  - source-sink scores: Spearman's ρ between S₁ and S₂ over all
//    populations, tested by permuting the second graph's labels (R:
//    sample.int(K) per draw, via RMersenneTwister, so draws match set.seed()),
//    with P = (1 + #{ρ_null ≥ ρ_obs − 10⁻¹²}) / (1 + #{finite ρ_null}).
//    Unlike gstudio 1.15.5, floating-point near-ties in S are merged first
//    (`mergeNearTies`, gstudio's `.merge_ties()`, as `SourceSinkTest` does):
//    structurally equal scores (e.g. along a chain of equal-degree nodes)
//    otherwise differ in their last bits and are ranked by rounding noise;
//  - edge direction: over the edges in both graphs, the share whose Δ has the
//    same sign in both, with an exact binomial (sign) test against ½. Edges
//    with Δ = 0 in either graph have no direction and are left out.
//
//  Fixture: `Tests/GraphTests/Fixtures/generate_gravity_congruence_fixtures.R`.
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// Whether two Population Graphs over the same populations agree on the direction of gene flow
/// (`AnalysisType.gravityCongruence`).
///
/// ## Usage
///
/// ```swift
/// if let congruence = GravityCongruenceAnalysis(graph1: beetles, graph2: cactus),
///    let run = congruence.perform(options: AnalysisOptions(iterations: 999, seed: 1)) {
///     print(run.outcome.rho, run.outcome.pValue ?? .nan, run.outcome.edgePValue ?? .nan)
/// }
/// ```
public struct GravityCongruenceAnalysis: Analysis {

    /// `AnalysisType.gravityCongruence`.
    public static let analysisType: AnalysisType = .gravityCongruence

    /// The populations, in the first graph's order, with their scores in both graphs.
    public let nodes: [GravityCongruenceNode]

    /// The edges in both graphs.
    public let edges: [GravityCongruenceEdge]

    /// The first graph's bandwidth multiplier γ.
    public let gamma1: Double

    /// The second graph's bandwidth multiplier γ.
    public let gamma2: Double

    /// Computes each graph's genetic gravity and pairs them up.
    ///
    /// - Parameters:
    ///   - graph1: The first graph.
    ///   - graph2: The second, over exactly the same populations.
    ///   - gamma1: The first graph's bandwidth multiplier (default `0.5`, degree-neutral).
    ///   - gamma2: The second graph's (default `0.5`).
    /// - Returns: `nil` if the graphs' populations differ (gstudio stops; compare graphs on different node sets
    ///   with `CongruenceTopology`), a name repeats, or gravity can't be computed for either graph.
    public init?(graph1: Graph, graph2: Graph, gamma1: Double = 0.5, gamma2: Double = 0.5) {
        let names = graph1.nodes.map(\.name)
        guard Set(names).count == names.count, graph2.nodes.count == names.count,
              Set(graph2.nodes.map(\.name)) == Set(names),
              let scores1 = SourceSinkScores(graph: graph1, gamma: gamma1),
              let scores2 = SourceSinkScores(graph: graph2, gamma: gamma2),
              let edges1 = GravityEdges(graph: graph1, gamma: gamma1),
              let edges2 = GravityEdges(graph: graph2, gamma: gamma2) else { return nil }
        let index = Dictionary(uniqueKeysWithValues: names.enumerated().map { ($1, $0) })

        let first = Dictionary(scores1.scores.map { ($0.stratum, $0) }, uniquingKeysWith: { a, _ in a })
        let second = Dictionary(scores2.scores.map { ($0.stratum, $0) }, uniquingKeysWith: { a, _ in a })
        var nodes: [GravityCongruenceNode] = []
        for name in names {
            guard let a = first[name], let b = second[name] else { return nil }
            nodes.append(GravityCongruenceNode(stratum: name, s1: a.s, s2: b.s, gravity1: a.gravity,
                                               gravity2: b.gravity, degree1: a.degree, degree2: b.degree))
        }

        /// Δ and weight on each edge, oriented from the earlier node to the later.
        func oriented(_ edges: [GravityEdge]) -> [Pair: (delta: Double, weight: Double)] {
            var result: [Pair: (delta: Double, weight: Double)] = [:]
            for edge in edges {
                guard let i = index[edge.from], let j = index[edge.to], i != j else { continue }
                result[Pair(i: min(i, j), j: max(i, j))] = (i < j ? edge.delta : -edge.delta, edge.weight)
            }
            return result
        }
        let d1 = oriented(edges1), d2 = oriented(edges2)
        self.edges = d1.keys.filter { d2[$0] != nil }.sorted { ($0.i, $0.j) < ($1.i, $1.j) }.compactMap { pair in
            guard let a = d1[pair], let b = d2[pair] else { return nil }
            return GravityCongruenceEdge(from: names[pair.i], to: names[pair.j], weight1: a.weight, weight2: b.weight,
                                         delta1: a.delta, delta2: b.delta)
        }
        self.nodes = nodes
        self.gamma1 = gamma1
        self.gamma2 = gamma2
    }

    /// Correlates the source-sink scores and, if `options.iterations > 0`, tests the correlation by permuting the
    /// second graph's population labels; tests edge direction with the sign test.
    ///
    /// - Parameter options: Permutation count and seed (R's `set.seed()` value).
    /// - Returns: The outcome; never `nil`.
    public func run(options: AnalysisOptions) -> GravityCongruenceOutcome? {
        let s1 = mergeNearTies(nodes.map(\.s1)), s2 = mergeNearTies(nodes.map(\.s2))
        let rho = spearmanCorrelation(s1, s2)
        var distribution: NullDistributionResult?
        if options.iterations > 0 {
            var rng = RMersenneTwister(seed: Int(truncatingIfNeeded: options.seed))
            let values = (0..<options.iterations).map { _ in
                let order = rng.sampleIndicesNoReplacement(n: nodes.count)   // R: sample.int(K)
                return spearmanCorrelation(s1, order.map { s2[$0] })
            }
            distribution = NullDistributionResult(analysisType: tag, observed: rho, values: values,
                                                  seed: options.seed)
        }
        let directed = edges.compactMap(\.isConcordant)
        let concordant = directed.filter { $0 }.count
        return GravityCongruenceOutcome(
            tag: tag, rho: rho, distribution: distribution, nodes: nodes, edges: edges,
            concordantEdges: concordant, directedEdges: directed.count,
            edgePValue: directed.isEmpty ? nil
                : binomialUpperTail(successes: concordant, trials: directed.count, probability: 0.5))
    }
}

/// An unordered pair of node indices, `i < j`.
private struct Pair: Hashable {
    let i: Int
    let j: Int
}
