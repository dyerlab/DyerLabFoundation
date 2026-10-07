//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DownstreamPopgraphTests.swift
//  Graph
//
//  Validates the downstream population-graph operations ported from gstudio
//  1.14 (the "mimic swift package" release) for numerical identity against
//  real R output:
//
//    - GraphAsymmetries          <- graph_asymmetries()
//    - AsymmetricWeights         <- asymmetric_weights()
//    - AsymmetricPopulationGraph <- asymmetric_popgraph()
//    - CongruenceTopology        <- congruence_topology()
//    - TestCongruence            <- test_congruence()   (== R's cor.test)
//    - Graph.subtractingEdges    <- `-.popgraph`
//
//  Fixtures/downstream_{real,small}.json were produced by
//  Fixtures/generate_downstream_fixtures.R (needs gstudio >= 1.14) running those
//  R functions on:
//    - the arapat / cornus population graphs, rebuilt edge-for-edge from the
//      existing popgraph_<name>_fixture.json so the input graph is identical to
//      what the Swift side constructs; and
//    - the small hand-built graphs from gstudio's own test files.
//

import Testing
import Foundation
@testable import Graph

private let fixtureTolerance = 1e-9

// MARK: - Fixture decoding

private struct FEdge: Decodable { let from: String; let to: String; let weight: Double? }
private struct FDirEdge: Decodable { let from: String; let to: String; let w_away: Double; let w_to: Double; let delta: Double }
private struct FAsymWeight: Decodable {
    let from: String; let to: String
    let pij: Double; let pji: Double; let cGD: Double
    let dij: Double; let dji: Double; let delta: Double
}
private struct FGraphAsym: Decodable { let bandwidth: [String: Double?]; let edges: [FDirEdge] }
private struct FAsymPopgraph: Decodable {
    let edges: [FEdge]; let edge_count: Int; let weight_sum: Double
}
private struct FRealDataset: Decodable {
    let nodes: [String]
    let edges: [FEdge]
    let graph_asymmetries: FGraphAsym
    let asymmetric_weights: [FAsymWeight]
    let asymmetric_popgraph: FAsymPopgraph
}
private struct FTestCongruence: Decodable { let estimate: Double; let statistic: Double; let df: Int; let p_value: Double }
private struct FCongruence: Decodable {
    let graph1_edges: [FEdge]; let graph2_edges: [FEdge]
    let graph1_nodes: [String]; let graph2_nodes: [String]
    let topology_nodes: [String]; let topology_edges: [FEdge]
    let topology_node_count: Int; let topology_edge_count: Int
    let test_congruence: FTestCongruence
}
private struct FOpsMinus: Decodable {
    let e1_nodes: [String]; let e1_edges: [FEdge]
    let e2_nodes: [String]; let e2_edges: [FEdge]
    let result_nodes: [String]; let result_edges: [FEdge]
    let result_node_count: Int; let result_edge_count: Int
}
private struct FSmallGraphAsym: Decodable {
    let nodes: [String]; let edges: [FEdge]
    let graph_asymmetries: FGraphAsym?
    let graph_asymmetries_flat: FGraphAsym?
    let graph_asymmetries_gamma: FGraphAsym?
    let bandwidth: Double?
    let asymmetric_weights: [FAsymWeight]?
    let asymmetric_popgraph: FAsymPopgraph?
}
private struct FSmall: Decodable {
    let triangle: FSmallGraphAsym
    let quad: FSmallGraphAsym
    let isolated: FSmallGraphAsym
    let underflow: FSmallGraphAsym
    let hub: FSmallGraphAsym
    let congruence: FCongruence
    let ops_minus: FOpsMinus
}

private func fixtureURL(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
}

private func loadReal() throws -> [String: FRealDataset] {
    try JSONDecoder().decode([String: FRealDataset].self,
                             from: Data(contentsOf: fixtureURL("downstream_real.json")))
}

private func loadSmall() throws -> FSmall {
    try JSONDecoder().decode(FSmall.self,
                             from: Data(contentsOf: fixtureURL("downstream_small.json")))
}

/// Builds a `Graph` with nodes in `nodeNames` order and one undirected edge per
/// entry of `edges`, preserving list order and `from → to` orientation — the
/// same construction the R fixture generator uses, so edge iteration lines up.
private func buildGraph(nodeNames: [String], edges: [FEdge]) -> Graph {
    let nodes = nodeNames.map { Node(name: $0, size: 1.0) }
    let byName = Dictionary(uniqueKeysWithValues: nodes.map { ($0.name, $0) })
    let graphEdges = edges.compactMap { edge -> Edge? in
        guard let a = byName[edge.from], let b = byName[edge.to] else { return nil }
        return Edge(fromNode: a, toNode: b, weight: edge.weight ?? 1.0)
    }
    return Graph(nodes: nodes, edges: graphEdges)
}

/// Canonical unordered key for an edge, orientation-independent.
private func key(_ a: String, _ b: String) -> String {
    a < b ? "\(a)\u{1}\(b)" : "\(b)\u{1}\(a)"
}

// MARK: - graph_asymmetries

private func assertGraphAsymmetriesMatch(_ graph: Graph, _ fixture: FGraphAsym?,
                                         bandwidth: GraphBandwidth = .local, scale: Double = 1.0,
                                         label: String, tolerance: Double = fixtureTolerance) throws {
    let fixture = try #require(fixture, "\(label): missing fixture")
    let result = try #require(GraphAsymmetries(graph: graph, bandwidth: bandwidth, scale: scale),
                              "\(label): GraphAsymmetries returned nil")

    #expect(result.bandwidth.count == fixture.bandwidth.count, "\(label): bandwidth node count")
    for (name, expected) in fixture.bandwidth {
        let actual = try #require(result.bandwidth[name], "\(label): missing bandwidth for \(name)")
        // R NA (isolated node) / Inf (flat kernel) arrive as JSON null.
        guard let expected else {
            #expect(!actual.isFinite, "\(label) bandwidth[\(name)]: \(actual) vs R NA/Inf")
            continue
        }
        #expect(abs(actual - expected) < tolerance, "\(label) bandwidth[\(name)]: \(actual) vs \(expected)")
    }

    // Compare per directed orientation, keyed by unordered pair.
    var expectedByPair: [String: (away: Double, to: Double, delta: Double, from: String)] = [:]
    for e in fixture.edges {
        expectedByPair[key(e.from, e.to)] = (e.w_away, e.w_to, e.delta, e.from)
    }
    #expect(result.edges.count == fixture.edges.count, "\(label): directional edge count")
    for edge in result.edges {
        let exp = try #require(expectedByPair[key(edge.from, edge.to)], "\(label): unexpected edge \(edge.from)-\(edge.to)")
        // Align orientation: if the fixture's `from` differs, swap away/to.
        let (expAway, expTo) = exp.from == edge.from ? (exp.away, exp.to) : (exp.to, exp.away)
        #expect(abs(edge.wAway - expAway) < tolerance, "\(label) \(edge.from)->\(edge.to) w_away: \(edge.wAway) vs \(expAway)")
        #expect(abs(edge.wTo - expTo) < tolerance, "\(label) \(edge.from)->\(edge.to) w_to: \(edge.wTo) vs \(expTo)")
    }
}

@Test(arguments: ["arapat", "cornus"])
func graphAsymmetriesMatchRealR(_ name: String) throws {
    let dataset = try #require(loadReal()[name])
    let graph = buildGraph(nodeNames: dataset.nodes, edges: dataset.edges)
    try assertGraphAsymmetriesMatch(graph, dataset.graph_asymmetries, label: name)
}

@Test func graphAsymmetriesMatchSmallHandGraphs() throws {
    let small = try loadSmall()
    try assertGraphAsymmetriesMatch(buildGraph(nodeNames: small.triangle.nodes, edges: small.triangle.edges),
                                    small.triangle.graph_asymmetries, label: "triangle")
    try assertGraphAsymmetriesMatch(buildGraph(nodeNames: small.quad.nodes, edges: small.quad.edges),
                                    small.quad.graph_asymmetries, label: "quad")
}

/// gstudio 1.15: `scale = Inf` is the flat kernel (every weight `1/kᵢ`), and
/// `gamma` is an alias for `scale`.
@Test func graphAsymmetriesFlatKernelAndGammaMatchR() throws {
    let small = try loadSmall()
    let triangle = buildGraph(nodeNames: small.triangle.nodes, edges: small.triangle.edges)
    try assertGraphAsymmetriesMatch(triangle, small.triangle.graph_asymmetries_flat,
                                    scale: .infinity, label: "triangle flat")
    try assertGraphAsymmetriesMatch(triangle, small.triangle.graph_asymmetries_gamma,
                                    scale: 0.5, label: "triangle gamma 0.5")
}

/// gstudio 1.15: isolated nodes no longer abort `graph_asymmetries()`; their
/// bandwidth is NA and they contribute no edges.
@Test func graphAsymmetriesAllowsIsolatedNodes() throws {
    let small = try loadSmall()
    let graph = buildGraph(nodeNames: small.isolated.nodes, edges: small.isolated.edges)
    try assertGraphAsymmetriesMatch(graph, small.isolated.graph_asymmetries, label: "isolated")
    let weights = try #require(small.isolated.asymmetric_weights)
    assertAsymmetricWeightsMatch(graph, weights, label: "isolated")
}

/// gstudio 1.15: when the plain Gaussian kernel underflows (tiny bandwidth), it
/// falls back to log-sum-exp instead of returning NaN.
@Test func graphAsymmetriesUnderflowFallbackMatchesR() throws {
    let small = try loadSmall()
    let graph = buildGraph(nodeNames: small.underflow.nodes, edges: small.underflow.edges)
    let bandwidth = try #require(small.underflow.bandwidth)
    try assertGraphAsymmetriesMatch(graph, small.underflow.graph_asymmetries,
                                    bandwidth: .fixed(bandwidth), label: "underflow")
}

@Test func graphAsymmetriesRejectsInvalidBandwidth() throws {
    let small = try loadSmall()
    let graph = buildGraph(nodeNames: small.triangle.nodes, edges: small.triangle.edges)
    #expect(GraphAsymmetries(graph: graph, scale: 0) == nil)
    #expect(GraphAsymmetries(graph: graph, scale: -1) == nil)
    #expect(GraphAsymmetries(graph: graph, bandwidth: .fixed(0)) == nil)
    #expect(GraphAsymmetries(graph: graph, bandwidth: .perNode(["A": 1, "B": 2])) == nil) // missing C
}

@Test func graphAsymmetriesScaleAndFixedBandwidth() throws {
    let small = try loadSmall()
    let graph = buildGraph(nodeNames: small.triangle.nodes, edges: small.triangle.edges)

    let base = try #require(GraphAsymmetries(graph: graph))
    let scaled = try #require(GraphAsymmetries(graph: graph, scale: 2))
    for (name, b) in base.bandwidth {
        #expect(abs((scaled.bandwidth[name] ?? 0) - 2 * b) < 1e-12)
    }

    let fixed = try #require(GraphAsymmetries(graph: graph, bandwidth: .fixed(2)))
    #expect(fixed.bandwidth.values.allSatisfy { abs($0 - 2) < 1e-12 })
}

// MARK: - asymmetric_weights

private func assertAsymmetricWeightsMatch(_ graph: Graph, _ fixture: [FAsymWeight], label: String) {
    let result = AsymmetricWeights(graph: graph)
    #expect(result.count == fixture.count, "\(label): row count")

    var expectedByPair: [String: FAsymWeight] = [:]
    for w in fixture { expectedByPair[key(w.from, w.to)] = w }

    for w in result {
        guard let exp = expectedByPair[key(w.from, w.to)] else {
            Issue.record("\(label): unexpected edge \(w.from)-\(w.to)")
            continue
        }
        let sameOrientation = exp.from == w.from
        let (expPij, expPji) = sameOrientation ? (exp.pij, exp.pji) : (exp.pji, exp.pij)
        let (expDij, expDji) = sameOrientation ? (exp.dij, exp.dji) : (exp.dji, exp.dij)
        let expDelta = sameOrientation ? exp.delta : -exp.delta
        #expect(abs(w.cGD - exp.cGD) < fixtureTolerance, "\(label) \(w.from)-\(w.to) cGD")
        #expect(abs(w.pij - expPij) < fixtureTolerance, "\(label) \(w.from)-\(w.to) pij: \(w.pij) vs \(expPij)")
        #expect(abs(w.pji - expPji) < fixtureTolerance, "\(label) \(w.from)-\(w.to) pji")
        #expect(abs(w.dij - expDij) < fixtureTolerance, "\(label) \(w.from)-\(w.to) dij: \(w.dij) vs \(expDij)")
        #expect(abs(w.dji - expDji) < fixtureTolerance, "\(label) \(w.from)-\(w.to) dji")
        #expect(abs(w.delta - expDelta) < fixtureTolerance, "\(label) \(w.from)-\(w.to) delta")
        // Structural: shares partition the edge weight.
        #expect(abs((w.dij + w.dji) - w.cGD) < 1e-9, "\(label) \(w.from)-\(w.to): dij+dji != cGD")
    }
}

@Test(arguments: ["arapat", "cornus"])
func asymmetricWeightsMatchRealR(_ name: String) throws {
    let dataset = try #require(loadReal()[name])
    let graph = buildGraph(nodeNames: dataset.nodes, edges: dataset.edges)
    assertAsymmetricWeightsMatch(graph, dataset.asymmetric_weights, label: name)
}

@Test func asymmetricWeightsMatchSmallHandGraph() throws {
    let small = try loadSmall()
    let quadWeights = try #require(small.quad.asymmetric_weights)
    assertAsymmetricWeightsMatch(buildGraph(nodeNames: small.quad.nodes, edges: small.quad.edges),
                                 quadWeights, label: "quad")
}

/// gstudio 1.15: a hub with more near-equal neighbour distances than
/// `perplexity` used to drive sigma to underflow (`0/0`); the data-driven
/// bracket, perplexity cap and stabilised kernel keep it finite.
@Test func asymmetricWeightsNearEqualHubMatchesR() throws {
    let small = try loadSmall()
    let weights = try #require(small.hub.asymmetric_weights)
    let graph = buildGraph(nodeNames: small.hub.nodes, edges: small.hub.edges)
    assertAsymmetricWeightsMatch(graph, weights, label: "hub")
    #expect(AsymmetricWeights(graph: graph).allSatisfy { $0.pij.isFinite && $0.pji.isFinite })
}

// MARK: - asymmetric_popgraph

private func assertAsymmetricPopulationGraphMatches(_ graph: Graph, _ fixture: FAsymPopgraph, label: String) {
    let directed = AsymmetricPopulationGraph(graph: graph)

    #expect(directed.edges.count == fixture.edge_count, "\(label): directed edge count")

    var expected: [String: Double] = [:]
    for e in fixture.edges { expected["\(e.from)\u{1}\(e.to)"] = e.weight ?? 0 }

    let names = Dictionary(uniqueKeysWithValues: directed.nodes.map { ($0.id, $0.name) })
    var actualSum = 0.0
    for edge in directed.edges {
        guard let from = names[edge.fromNode], let to = names[edge.toNode] else {
            Issue.record("\(label): edge with unknown endpoint"); continue
        }
        actualSum += edge.weight
        guard let expWeight = expected["\(from)\u{1}\(to)"] else {
            Issue.record("\(label): unexpected directed edge \(from)->\(to)"); continue
        }
        #expect(abs(edge.weight - expWeight) < fixtureTolerance, "\(label) \(from)->\(to): \(edge.weight) vs \(expWeight)")
    }
    #expect(abs(actualSum - fixture.weight_sum) < 1e-8, "\(label): total weight \(actualSum) vs \(fixture.weight_sum)")
}

@Test(arguments: ["arapat", "cornus"])
func asymmetricPopulationGraphMatchesRealR(_ name: String) throws {
    let dataset = try #require(loadReal()[name])
    let graph = buildGraph(nodeNames: dataset.nodes, edges: dataset.edges)
    assertAsymmetricPopulationGraphMatches(graph, dataset.asymmetric_popgraph, label: name)
}

@Test func asymmetricPopulationGraphPreservesTotalDistance() throws {
    let small = try loadSmall()
    let fixture = try #require(small.quad.asymmetric_popgraph)
    let graph = buildGraph(nodeNames: small.quad.nodes, edges: small.quad.edges)
    let directed = AsymmetricPopulationGraph(graph: graph)

    #expect(directed.edges.count == 2 * graph.edges.count)
    let undirectedTotal = graph.edges.reduce(0) { $0 + $1.weight }
    let directedTotal = directed.edges.reduce(0) { $0 + $1.weight }
    #expect(abs(directedTotal - undirectedTotal) < 1e-9)
    #expect(abs(directedTotal - fixture.weight_sum) < 1e-9)
    #expect(directed.edges.allSatisfy { $0.weight > 0 })
}

// MARK: - congruence_topology

@Test func congruenceTopologyMatchesR() throws {
    let c = try loadSmall().congruence
    let g1 = buildGraph(nodeNames: c.graph1_nodes, edges: c.graph1_edges)
    let g2 = buildGraph(nodeNames: c.graph2_nodes, edges: c.graph2_edges)

    let cong = CongruenceTopology(g1, g2)
    #expect(cong.nodes.count == c.topology_node_count)
    #expect(cong.nodes.map { $0.name } == c.topology_nodes)
    #expect(cong.edges.count == c.topology_edge_count)

    let names = Dictionary(uniqueKeysWithValues: cong.nodes.map { ($0.id, $0.name) })
    let actual = Set(cong.edges.map { key(names[$0.fromNode]!, names[$0.toNode]!) })
    let expected = Set(c.topology_edges.map { key($0.from, $0.to) })
    #expect(actual == expected)
}

// MARK: - test_congruence

@Test func testCongruenceMatchesRCorTest() throws {
    let c = try loadSmall().congruence
    let g1 = buildGraph(nodeNames: c.graph1_nodes, edges: c.graph1_edges)
    let g2 = buildGraph(nodeNames: c.graph2_nodes, edges: c.graph2_edges)

    let result = try #require(TestCongruence(g1, g2))
    #expect(result.df == c.test_congruence.df)
    #expect(abs(result.correlation - c.test_congruence.estimate) < 1e-9,
            "r: \(result.correlation) vs \(c.test_congruence.estimate)")
    #expect(abs(result.statistic - c.test_congruence.statistic) < 1e-9,
            "t: \(result.statistic) vs \(c.test_congruence.statistic)")
    #expect(abs(result.pValue - c.test_congruence.p_value) < 1e-7,
            "p: \(result.pValue) vs \(c.test_congruence.p_value)")
}

@Test func testCongruenceNilWhenNoSharedNodes() {
    let g1 = buildGraph(nodeNames: ["A", "B", "C"], edges: [FEdge(from: "A", to: "B", weight: 1), FEdge(from: "B", to: "C", weight: 1)])
    let g2 = buildGraph(nodeNames: ["X", "Y", "Z"], edges: [FEdge(from: "X", to: "Y", weight: 1), FEdge(from: "Y", to: "Z", weight: 1)])
    #expect(TestCongruence(g1, g2) == nil)
}

// MARK: - graph subtraction (`-.popgraph`)

@Test func graphSubtractionMatchesR() throws {
    let ops = try loadSmall().ops_minus
    let e1 = buildGraph(nodeNames: ops.e1_nodes, edges: ops.e1_edges)
    let e2 = buildGraph(nodeNames: ops.e2_nodes, edges: ops.e2_edges)

    let e3 = try #require(e1.subtractingEdges(in: e2))
    #expect(e3.nodes.count == ops.result_node_count)
    #expect(e3.edges.count == ops.result_edge_count)

    let names = Dictionary(uniqueKeysWithValues: e3.nodes.map { ($0.id, $0.name) })
    let actual = Set(e3.edges.map { key(names[$0.fromNode]!, names[$0.toNode]!) })
    let expected = Set(ops.result_edges.map { key($0.from, $0.to) })
    #expect(actual == expected)
}

@Test func graphSubtractionRejectsMismatchedNodeSets() {
    let a = buildGraph(nodeNames: ["A", "B", "C"], edges: [FEdge(from: "A", to: "B", weight: 1)])
    let b = buildGraph(nodeNames: ["A", "B"], edges: [FEdge(from: "A", to: "B", weight: 1)])
    #expect(a.subtractingEdges(in: b) == nil)      // b is missing C
    #expect(b.subtractingEdges(in: a) != nil)      // a covers b's node set
}
