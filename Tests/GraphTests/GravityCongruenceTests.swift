//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GravityCongruenceTests.swift
//  GraphTests
//
//  GravityCongruenceAnalysis against gstudio's gravity_congruence() (1.15.5):
//  the source-sink correlation (near-ties merged) and its label-permutation P
//  draw for draw, the
//  sign test, and the nodes and shared-edges tables
//  (Fixtures/generate_gravity_congruence_fixtures.R).
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
import Matrix
@testable import Graph

struct GravityCongruenceTests {

    struct FEdge: Decodable { let from: String; let to: String; let weight: Double }
    struct FGraph: Decodable { let nodes: [String]; let edges: [FEdge] }
    struct FNode: Decodable {
        let Stratum: String
        let S1: Double, S2: Double, gravity1: Double, gravity2: Double
        let degree1: Int, degree2: Int
        let concordance: String
        enum CodingKeys: String, CodingKey {
            case Stratum, concordance
            case S1 = "S.1", S2 = "S.2", gravity1 = "gravity.1", gravity2 = "gravity.2"
            case degree1 = "degree.1", degree2 = "degree.2"
        }
    }
    struct FSharedEdge: Decodable {
        let from: String, to: String
        let weight1: Double, weight2: Double, delta1: Double, delta2: Double
        let concordant: Bool?
        enum CodingKeys: String, CodingKey {
            case from, to, concordant
            case weight1 = "weight.1", weight2 = "weight.2", delta1 = "delta.1", delta2 = "delta.2"
        }
    }
    struct FCase: Decodable {
        let graph1: FGraph, graph2: FGraph
        let gamma1: Double, gamma2: Double
        let seed: UInt64, nperm: Int
        let rho: Double, p_rho: Double, rho_merged: Double, p_rho_merged: Double
        let edge_concordance: Double, directed_edges: Int, p_edge: Double
        let nodes: [FNode]
        let edges: [FSharedEdge]
    }

    private func cases() throws -> [String: FCase] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/gravity_congruence_fixtures.json")
        return try JSONDecoder().decode([String: FCase].self, from: Data(contentsOf: url))
    }

    private func graph(_ fixture: FGraph) -> Graph {
        let nodes = fixture.nodes.map { Node(name: $0, size: 1) }
        let byName = Dictionary(uniqueKeysWithValues: nodes.map { ($0.name, $0) })
        return Graph(nodes: nodes, edges: fixture.edges.compactMap { edge in
            guard let from = byName[edge.from], let to = byName[edge.to] else { return nil }
            return Edge(fromNode: from, toNode: to, weight: edge.weight)
        })
    }

    private func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-10) -> Bool { abs(a - b) < tolerance }

    @Test(arguments: ["chain", "gravity"])
    func matchesGstudio(_ name: String) throws {
        let c = try #require(try cases()[name])
        let analysis = try #require(GravityCongruenceAnalysis(graph1: graph(c.graph1), graph2: graph(c.graph2),
                                                              gamma1: c.gamma1, gamma2: c.gamma2))
        let outcome = try #require(analysis.run(options: AnalysisOptions(iterations: c.nperm, seed: c.seed)))
        #expect(close(outcome.rho, c.rho_merged), "\(name) rho \(outcome.rho) vs \(c.rho_merged)")
        #expect(close(outcome.pValue ?? .nan, c.p_rho_merged, 1e-12), "\(name) P(rho)")
        #expect(outcome.directedEdges == c.directed_edges)
        #expect(close(outcome.edgeConcordance ?? .nan, c.edge_concordance))
        #expect(close(outcome.edgePValue ?? .nan, c.p_edge, 1e-12))

        #expect(outcome.nodes.map(\.stratum) == c.nodes.map(\.Stratum))
        for (swift, r) in zip(outcome.nodes, c.nodes) {
            #expect(close(swift.s1, r.S1) && close(swift.s2, r.S2), "\(name) \(r.Stratum) S")
            #expect(close(swift.gravity1, r.gravity1) && close(swift.gravity2, r.gravity2))
            #expect(swift.degree1 == r.degree1 && swift.degree2 == r.degree2)
            #expect(swift.concordance.rawValue == r.concordance, "\(name) \(r.Stratum)")
        }
        #expect(outcome.edges.count == c.edges.count)
        for (swift, r) in zip(outcome.edges, c.edges) {
            #expect(swift.from == r.from && swift.to == r.to, "\(name) edge order")
            #expect(close(swift.delta1, r.delta1) && close(swift.delta2, r.delta2), "\(name) \(r.from)-\(r.to)")
            #expect(close(swift.weight1, r.weight1) && close(swift.weight2, r.weight2))
            #expect(swift.isConcordant == r.concordant)
        }
    }

    @Test func nearTiesAreWhatSeparateUsFromGstudio() throws {
        let all = try cases()
        let chain = try #require(all["chain"]), gravity = try #require(all["gravity"])
        #expect(chain.rho == chain.rho_merged && chain.p_rho == chain.p_rho_merged)   // no near-ties
        #expect(gravity.rho != gravity.rho_merged)                                      // seven near-tied S₂
    }

    @Test func differentPopulationsHaveNoAnalysis() throws {
        let c = try #require(try cases()["chain"])
        let g1 = graph(c.graph1)
        let g2 = graph(FGraph(nodes: c.graph2.nodes.dropLast() + ["Other"],
                              edges: c.graph2.edges.filter { $0.from != "P10" && $0.to != "P10" }))
        #expect(GravityCongruenceAnalysis(graph1: g1, graph2: g2) == nil)
    }

    @Test func aGraphIsCongruentWithItself() throws {
        let c = try #require(try cases()["chain"])
        let analysis = try #require(GravityCongruenceAnalysis(graph1: graph(c.graph1), graph2: graph(c.graph1)))
        let run = try #require(analysis.perform(options: AnalysisOptions(iterations: 99, seed: 1)))
        #expect(close(run.outcome.rho, 1))
        #expect(run.outcome.edgeConcordance == 1)
        #expect(run.report.results.contains("Spearman's ρ = 1"))
        #expect(run.report.methods.contains("permutations of the second graph's population labels"))
    }
}
