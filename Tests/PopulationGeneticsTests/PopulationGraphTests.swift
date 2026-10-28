//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopulationGraphTests.swift
//  PopulationGeneticsTests
//
//  Validates `PopulationGraph()` for numerical identity against gstudio's real
//  `popgraph()` (Dyer & Nason 2004). gstudio's own `test-popgraph.R` carries no
//  real coverage of popgraph() itself (just a commented-out theoretical note) —
//  there was no existing R fixture to reuse, so each fixture here was produced
//  by actually running `gstudio::popgraph()`/`igraph` through Rscript on real,
//  independent, published datasets bundled with gstudio:
//
//  - `arapat`: 363 individuals, 39 populations, 8 microsatellite/AFLP loci.
//  - `cornus`: 451 individuals, 5 populations, 5 microsatellite loci
//    (allele labels are size-based, e.g. "157"/"165", unlike arapat's 2-digit
//    codes — different enough to exercise the codebook/import path distinctly).
//
//  `Fixtures/<name>_genotypes.csv` is the dataset exported unmodified from R;
//  `Fixtures/popgraph_<name>_fixture.json` is the real edge list and node
//  sizes from `popgraph(x = to_mv(<name>[,-metadata]), groups = <name>$Population)`
//  (R/gstudio/igraph 1.13/2.3.3) — not a hand-derived or synthetic expectation.
//
//  Created by Rodney Dyer on 2026.08.26.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Testing
import Foundation
import Matrix
import Graph
@testable import PopulationGenetics

private struct FixtureEdge: Decodable { let from: String; let to: String; let weight: Double }
private struct FixtureNode: Decodable { let name: String; let size: Double }
private struct Fixture: Decodable { let edges: [FixtureEdge]; let nodes: [FixtureNode] }

struct RealDataset {
    let name: String
    let nameColumn: String
}

private let realDatasets = [
    RealDataset(name: "arapat", nameColumn: "ID"),
    RealDataset(name: "cornus", nameColumn: "ID"),
]

struct PopulationGraphTests {

    private func fixtureURL(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
    }

    private func loadRGraph(_ dataset: RealDataset) throws -> Graph {
        let csv = try String(contentsOf: fixtureURL("\(dataset.name)_genotypes.csv"), encoding: .utf8)
        let layout = PopulationImportLayout(strataColumns: ["Population"], nameColumn: dataset.nameColumn)
        let imported = try importPopulationTable(csv: csv, layout: layout)
        let matrix = imported.matrix

        let groups = matrix.individuals.map { individual in
            imported.strata[individual.id]?.first(where: { $0.level == "Population" })?.name ?? ""
        }

        let mv = matrix.multivariateMatrix()
        let graph = PopulationGraph(x: mv, groups: groups)
        #expect(graph != nil, "\(dataset.name): PopulationGraph returned nil")
        return try #require(graph)
    }

    private func loadFixture(_ dataset: RealDataset) throws -> Fixture {
        let data = try Data(contentsOf: fixtureURL("popgraph_\(dataset.name)_fixture.json"))
        return try JSONDecoder().decode(Fixture.self, from: data)
    }

    // MARK: - Numerical identity against real R output

    @Test(arguments: realDatasets)
    func edgeSetAndWeightsMatchRealRPopgraph(_ dataset: RealDataset) throws {
        let graph = try loadRGraph(dataset)
        let fixture = try loadFixture(dataset)

        var swiftEdges: [Set<String>: Double] = [:]
        for edge in graph.edges {
            guard let fromNode = graph.node(id: edge.fromNode), let toNode = graph.node(id: edge.toNode) else {
                Issue.record("\(dataset.name): edge references a node not present in the graph")
                continue
            }
            swiftEdges[Set([fromNode.name, toNode.name])] = edge.weight
        }

        var rEdges: [Set<String>: Double] = [:]
        for edge in fixture.edges {
            rEdges[Set([edge.from, edge.to])] = edge.weight
        }

        #expect(swiftEdges.count == rEdges.count, "\(dataset.name): edge count mismatch")

        for (pair, rWeight) in rEdges {
            guard let swiftWeight = swiftEdges[pair] else {
                Issue.record("\(dataset.name): edge \(pair) present in R output but missing from Swift PopulationGraph")
                continue
            }
            #expect(abs(swiftWeight - rWeight) < 1e-9,
                    "\(dataset.name) edge \(pair): swift=\(swiftWeight) R=\(rWeight)")
        }

        for pair in swiftEdges.keys where rEdges[pair] == nil {
            Issue.record("\(dataset.name): edge \(pair) present in Swift PopulationGraph but missing from R output")
        }
    }

    @Test(arguments: realDatasets)
    func nodeSizesMatchRealRPopgraph(_ dataset: RealDataset) throws {
        let graph = try loadRGraph(dataset)
        let fixture = try loadFixture(dataset)

        let swiftSizes = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.name, $0.size) })
        let rSizes = Dictionary(uniqueKeysWithValues: fixture.nodes.map { ($0.name, $0.size) })

        #expect(swiftSizes.count == rSizes.count, "\(dataset.name): node count mismatch")
        for (name, rSize) in rSizes {
            guard let swiftSize = swiftSizes[name] else {
                Issue.record("\(dataset.name): node \(name) present in R output but missing from Swift PopulationGraph")
                continue
            }
            #expect(abs(swiftSize - rSize) < 1e-9, "\(dataset.name) node \(name): swift=\(swiftSize) R=\(rSize)")
        }
    }

    // MARK: - Structural invariants (independent of R)

    @Test(arguments: realDatasets)
    func nodeCountMatchesDistinctGroupCount(_ dataset: RealDataset) throws {
        let csv = try String(contentsOf: fixtureURL("\(dataset.name)_genotypes.csv"), encoding: .utf8)
        let layout = PopulationImportLayout(strataColumns: ["Population"], nameColumn: dataset.nameColumn)
        let imported = try importPopulationTable(csv: csv, layout: layout)
        let groups = imported.matrix.individuals.map { individual in
            imported.strata[individual.id]?.first(where: { $0.level == "Population" })?.name ?? ""
        }

        let graph = try loadRGraph(dataset)
        #expect(graph.nodes.count == Set(groups).count)
    }

    @Test(arguments: realDatasets)
    func hasNoSelfLoops(_ dataset: RealDataset) throws {
        let graph = try loadRGraph(dataset)
        for edge in graph.edges {
            #expect(edge.fromNode != edge.toNode, "\(dataset.name): self-loop on \(edge.fromNode)")
        }
    }

    @Test(arguments: realDatasets)
    func allEdgeWeightsArePositive(_ dataset: RealDataset) throws {
        let graph = try loadRGraph(dataset)
        for edge in graph.edges {
            #expect(edge.weight > 0, "\(dataset.name): non-positive edge weight \(edge.weight)")
        }
    }

    @Test(arguments: realDatasets)
    func edgesConnectOnlyDistinctExistingNodes(_ dataset: RealDataset) throws {
        let graph = try loadRGraph(dataset)
        let nodeIDs = Set(graph.nodes.map(\.id))
        for edge in graph.edges {
            #expect(nodeIDs.contains(edge.fromNode), "\(dataset.name): edge references unknown fromNode")
            #expect(nodeIDs.contains(edge.toNode), "\(dataset.name): edge references unknown toNode")
        }
    }

    // MARK: - Minimal synthetic sanity check (no R involved)

    @Test func twoWellSeparatedGroupsProduceASingleConnectingEdge() throws {
        // K=2 is the smallest non-trivial case: with only two groups there is
        // exactly one pairwise distance and nothing else to condition on, so
        // the partial-correlation test is vacuous and the edge must always
        // survive. This exercises the pipeline independent of any R fixture.
        let x = Matrix(10, 1, Vector(
            [0.0, 0.1, -0.1, 0.05, -0.05, 10.0, 10.1, 9.9, 10.05, 9.95]
        ))
        let groups = Array(repeating: "A", count: 5) + Array(repeating: "B", count: 5)

        let graph = try #require(PopulationGraph(x: x, groups: groups))
        #expect(graph.nodes.count == 2)
        #expect(graph.edges.count == 1)
    }
}
