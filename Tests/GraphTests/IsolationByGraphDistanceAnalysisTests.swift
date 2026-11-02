//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IsolationByGraphDistanceAnalysisTests.swift
//  GraphTests
//
//  R parity of the underlying tests lives in GeneticGravityInferenceTests
//  (the free functions delegate to these analyses); this suite checks the
//  plot-ready points and lines.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Testing
import Matrix
@testable import Graph

@MainActor
struct IsolationByGraphDistanceAnalysisTests {

    private func latitudes(_ graph: Graph) -> [String: Double] {
        Dictionary(uniqueKeysWithValues: graph.nodes.compactMap { node in
            node.coordinate.map { (node.name, $0.latitude) }
        })
    }

    @Test func cgdScatterHasOnePointPerConnectedPair() throws {
        let graph = Graph.lophoGraph
        let analysis = try #require(IsolationByGraphDistanceAnalysis(graph: graph,
                                                                     separation: .positions(latitudes(graph))))
        let outcome = try #require(analysis.run(options: AnalysisOptions(iterations: 19, seed: 3)))
        let legacy = try #require(IsolationByGraphDistance(graph: graph, separation: .positions(latitudes(graph)),
                                                           permutations: 19, seed: 3))

        #expect(outcome.statistic == legacy.statistic)
        #expect(outcome.pValue == legacy.pValue)
        #expect(outcome.scatter.points.count == legacy.pairs)
        #expect(outcome.scatter.series.first?.line?.slope == legacy.slope)
        #expect(outcome.scatter.yLabel == "cGD")
        let names = Set(graph.nodes.map(\.name))
        #expect(outcome.scatter.points.allSatisfy { names.contains($0.from) && names.contains($0.to) })
    }

    @Test func directionalScatterSplitsForwardAndReversePairs() throws {
        let graph = Graph.lophoGraph
        let latitude = latitudes(graph)
        let analysis = try #require(DirectionalIsolationByGraphDistanceAnalysis(graph: graph,
                                                                                separation: .positions(latitude)))
        let outcome = try #require(analysis.run(options: AnalysisOptions()))
        let legacy = try #require(DirectionalIsolationByGraphDistance(graph: graph, separation: .positions(latitude)))

        #expect(outcome.result == legacy)
        #expect(outcome.statistic == legacy.deltaR2)
        #expect(outcome.pValue == nil)
        #expect(outcome.forwardPoints.count + outcome.reversePoints.count == legacy.pairs)
        // Forward means northward: the destination lies further north.
        #expect(outcome.forwardPoints.allSatisfy { latitude[$0.to]! > latitude[$0.from]! })
        #expect(outcome.reversePoints.allSatisfy { latitude[$0.to]! < latitude[$0.from]! })

        let series = outcome.scatter.series
        #expect(series.map(\.name) == ["Forward", "Reverse"])
        #expect(series[0].line == RegressionLine(intercept: outcome.intercept, slope: legacy.forwardSlope))
        #expect(series[1].line == RegressionLine(intercept: outcome.intercept, slope: legacy.reverseSlope))
    }

    // MARK: - Reports

    @Test func reportsNameTheDistancesAndFillEveryPlaceholder() throws {
        let graph = Graph.lophoGraph
        let separation = GraphSeparation.positions(latitudes(graph))
        let cgd = try #require(IsolationByGraphDistanceAnalysis(graph: graph, separation: separation,
                                                                separationLabel: "Latitude")?
            .perform(options: AnalysisOptions(iterations: 19, seed: 3)))
        let directional = try #require(DirectionalIsolationByGraphDistanceAnalysis(graph: graph, separation: separation,
                                                                                   separationLabel: "Latitude")?
            .perform(options: AnalysisOptions()))

        for report in [cgd.report, directional.report] {
            #expect(!(report.methods + report.results).contains("{"), "\(report.methods) \(report.results)")
        }
        #expect(cgd.report.methods.contains("with latitude among \(graph.nodes.count) populations"))
        #expect(cgd.report.methods.contains("(\(cgd.outcome.mantel.pairCount) connected pairs)"))
        #expect(cgd.report.results.contains("Mantel r = \(AnalysisReport.number(cgd.outcome.statistic))"))
        #expect(directional.report.methods.contains("γ = 0.500"))
        #expect(directional.report.results.contains("ΔR² = \(AnalysisReport.number(directional.outcome.statistic))"))
    }
}
