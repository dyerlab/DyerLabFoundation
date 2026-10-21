//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  KamadaKawaiTests.swift
//  Graph
//
//  Validates KamadaKawaiSolver against igraph::layout_with_kk() and gstudio's
//  layout = "kk". Fixtures/layout_fixtures.json was produced by
//  Fixtures/generate_layout_fixtures.R from:
//    - an unweighted 6-ring;
//    - a weighted graph with a second component (max-distance fill);
//    - the arapat / cornus population graphs through gstudio's median-floored
//      "kk" layout function.
//

import Testing
import Foundation
import Matrix
@testable import Graph

// MARK: - Fixture decoding

private struct FLayoutEdge: Decodable {
    let from: String
    let to: String
    let weight: Double?
}

private struct FLayoutCase: Decodable {
    let nodes: [String]
    let edges: [FLayoutEdge]
    let weighting: String
    let x: [Double]
    let y: [Double]
    let earlyX: [Double]
    let earlyY: [Double]

    enum CodingKeys: String, CodingKey {
        case nodes, edges, weighting, x, y
        case earlyX = "early_x", earlyY = "early_y"
    }

    var graph: Graph {
        let nodes = self.nodes.map { Node(name: $0, size: 1.0) }
        let byName = Dictionary(uniqueKeysWithValues: nodes.map { ($0.name, $0) })
        let edges = self.edges.compactMap { edge -> Edge? in
            guard let a = byName[edge.from], let b = byName[edge.to] else { return nil }
            return Edge(fromNode: a, toNode: b, weight: edge.weight ?? 1.0)
        }
        return Graph(nodes: nodes, edges: edges)
    }

    var kkWeighting: KamadaKawaiWeighting {
        switch weighting {
        case "unweighted": .unweighted
        case "edgeWeights": .edgeWeights
        default: .flooredEdgeWeights()
        }
    }
}

private func loadCases() throws -> [String: FLayoutCase] {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent("layout_fixtures.json")
    return try JSONDecoder().decode([String: FLayoutCase].self, from: Data(contentsOf: url))
}

private func expectLayout(_ layout: [SIMD2<Double>], matches x: [Double], _ y: [Double],
                          _ nodes: [String], _ name: String) {
    #expect(layout.count == nodes.count)
    for (i, point) in layout.enumerated() {
        #expect(isApprox(point.x, x[i], tolerance: 1e-8), "\(name) x[\(nodes[i])]: \(point.x) vs \(x[i])")
        #expect(isApprox(point.y, y[i], tolerance: 1e-8), "\(name) y[\(nodes[i])]: \(point.y) vs \(y[i])")
    }
}

/// Kamada–Kawai energy Σ ½·k_ij·(|p_i − p_j| − l_ij)², with igraph's
/// constants (`kkconst = n`, `L = √n / max d`, disconnected pairs at max d).
private func stressEnergy(_ p: [SIMD2<Double>], _ distances: Matrix) -> Double {
    let n = p.count
    var maxD = 0.0
    for i in 0..<n { for j in 0..<n where distances[i, j].isFinite { maxD = max(maxD, distances[i, j]) } }
    let scale = Double(n).squareRoot() / maxD
    var energy = 0.0
    for i in 0..<n {
        for j in (i + 1)..<n {
            let d = min(distances[i, j], maxD)
            let gap = ((p[i] - p[j]) * (p[i] - p[j])).sum().squareRoot() - scale * d
            energy += 0.5 * (Double(n) / (d * d)) * gap * gap
        }
    }
    return energy
}

/// Node-index groups of mutually reachable nodes.
private func components(_ distances: Matrix) -> [[Int]] {
    var seen = Set<Int>()
    var result: [[Int]] = []
    for i in 0..<distances.rows where !seen.contains(i) {
        let group = (0..<distances.rows).filter { distances[i, $0].isFinite }
        seen.formUnion(group)
        result.append(group)
    }
    return result
}

/// RMS distance between two point sets after centring and the best rotation
/// or reflection of `a` onto `b`.
private func procrustesRMS(_ a: [SIMD2<Double>], _ b: [SIMD2<Double>]) -> Double {
    func centred(_ p: [SIMD2<Double>]) -> [SIMD2<Double>] {
        let mean = p.reduce(.zero, +) / Double(p.count)
        return p.map { $0 - mean }
    }
    let target = centred(b)
    func bestRotationRMS(_ source: [SIMD2<Double>]) -> Double {
        var dot = 0.0, cross = 0.0
        for (s, t) in zip(source, target) {
            dot += s.x * t.x + s.y * t.y
            cross += s.x * t.y - s.y * t.x
        }
        let angle = atan2(cross, dot)
        let (c, s) = (cos(angle), sin(angle))
        let squared = zip(source, target).map { p, t -> Double in
            let r = SIMD2(c * p.x - s * p.y, s * p.x + c * p.y) - t
            return (r * r).sum()
        }
        return (squared.reduce(0, +) / Double(source.count)).squareRoot()
    }
    let source = centred(a)
    return min(bestRotationRMS(source), bestRotationRMS(source.map { SIMD2(-$0.x, $0.y) }))
}

// MARK: - R parity

@Suite("Kamada–Kawai layout")
struct KamadaKawaiTests {

    @Test("First 100 moves follow igraph's exact trajectory",
          arguments: ["ring", "split", "arapat", "cornus"])
    func matchesREarly(name: String) throws {
        let fixture = try #require(try loadCases()[name])
        let layout = try fixture.graph.kamadaKawaiLayout(weighting: fixture.kkWeighting, maxIterations: 100)
        expectLayout(layout, matches: fixture.earlyX, fixture.earlyY, fixture.nodes, name)
    }

    @Test("Full layout matches igraph::layout_with_kk() / gstudio layout = \"kk\"",
          arguments: ["ring", "split", "cornus"])
    func matchesR(name: String) throws {
        let fixture = try #require(try loadCases()[name])
        let layout = try fixture.graph.kamadaKawaiLayout(weighting: fixture.kkWeighting)
        expectLayout(layout, matches: fixture.x, fixture.y, fixture.nodes, name)
    }

    /// arapat has four components and is still moving at 50·n moves, so
    /// rounding differences eventually pick different nodes to move than igraph
    /// does. The result is an equally good layout: the same energy, and the same
    /// shape within each component. Only the placement of the disconnected
    /// components relative to each other differs, because the max-distance
    /// springs that hold them together barely constrain them.
    @Test("Full arapat layout is functionally equivalent to gstudio's")
    func matchesRFunctionally() throws {
        let fixture = try #require(try loadCases()["arapat"])
        let graph = fixture.graph
        let distances = try graph.kamadaKawaiDistances(weighting: fixture.kkWeighting)
        let layout = try graph.kamadaKawaiLayout(weighting: fixture.kkWeighting)
        let reference = zip(fixture.x, fixture.y).map { SIMD2($0, $1) }

        let swiftEnergy = stressEnergy(layout, distances)
        let rEnergy = stressEnergy(reference, distances)
        #expect(abs(swiftEnergy - rEnergy) / rEnergy < 0.005, "energy \(swiftEnergy) vs R \(rEnergy)")

        let span = (reference.map(\.x).max()! - reference.map(\.x).min()!)
        for component in components(distances) where component.count >= 4 {
            let rms = procrustesRMS(component.map { layout[$0] }, component.map { reference[$0] })
            #expect(rms < 0.01 * span, "component of \(component.count): RMS \(rms)")
        }
    }

    @Test("Floored weighting adds a quarter of the median edge weight")
    func flooredDistances() throws {
        let a = Node(name: "A", size: 1), b = Node(name: "B", size: 1), c = Node(name: "C", size: 1)
        let graph = Graph(nodes: [a, b, c], edges: [
            Edge(fromNode: a, toNode: b, weight: 1),
            Edge(fromNode: b, toNode: c, weight: 3),
        ])
        // median = 2 → lengths 1.5 and 3.5
        let d = try graph.kamadaKawaiDistances(weighting: .flooredEdgeWeights())
        #expect(isApprox(d[0, 1], 1.5))
        #expect(isApprox(d[1, 2], 3.5))
        #expect(isApprox(d[0, 2], 5.0))
    }

    @Test("Non-positive edge lengths are rejected, as in igraph")
    func rejectsNonPositiveWeights() {
        let a = Node(name: "A", size: 1), b = Node(name: "B", size: 1)
        let graph = Graph(nodes: [a, b], edges: [Edge(fromNode: a, toNode: b, weight: 0)])
        #expect(throws: KamadaKawaiError.nonPositiveWeight(0)) {
            try graph.kamadaKawaiLayout(weighting: .edgeWeights)
        }
    }

    @Test("A fixed node stays where it is held")
    func fixedNodeStaysPut() throws {
        var solver = try KamadaKawaiSolver(graph: Graph.lophoGraph)
        let anchor = SIMD2<Double>(10, -4)
        solver.fixedPositions[0] = anchor
        solver.move(0, to: anchor)
        solver.run()
        #expect(solver.position(0) == anchor)
        #expect(solver.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    }

    @Test("Edgeless graph lays out as finite points instead of NaN")
    func edgelessGraph() throws {
        let graph = Graph(nodes: ["A", "B", "C"].map { Node(name: $0, size: 1) })
        let layout = try graph.kamadaKawaiLayout()
        #expect(layout.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    }
}

// MARK: - Orchestrator integration

@Suite("Kamada–Kawai in LayoutOrchestrator")
@MainActor
struct KamadaKawaiOrchestratorTests {

    private func kkConfig() -> LayoutConfiguration {
        var config = LayoutConfiguration.default
        config.algorithm = .kamadaKawai
        return config
    }

    @Test("Settles on a real distance-weighted graph within its move budget")
    func settlesOnLopho() throws {
        let graph = Graph.lophoGraph
        let orchestrator = LayoutOrchestrator(graph: graph, config: kkConfig())
        for _ in 0..<200 where !orchestrator.isSettled {
            orchestrator.step()
        }
        #expect(orchestrator.isSettled)
        // 50·n moves at n moves per frame.
        #expect(orchestrator.iteration == 50)
    }

    @Test("World positions are the R layout scaled so the mean edge is k long")
    func positionsMatchSolver() throws {
        let graph = Graph.lophoGraph
        let config = kkConfig()
        let orchestrator = LayoutOrchestrator(graph: graph, config: config)
        while !orchestrator.isSettled { orchestrator.step() }

        let reference = try graph.kamadaKawaiLayout(weighting: config.kamadaKawaiWeighting)
        let p0 = orchestrator.state.positions[0], p1 = orchestrator.state.positions[1]
        let r0 = reference[0], r1 = reference[1]
        // Uniform scale: world vectors are parallel to, and a fixed multiple of, R's.
        let world = SIMD2<Double>(Double(p1.x - p0.x), Double(p1.y - p0.y))
        let ref = r1 - r0
        let scale = world.x / ref.x
        #expect(isApprox(world.y, ref.y * scale, tolerance: 1e-3))
        #expect(orchestrator.state.positions.allSatisfy { $0.z == 0 })
    }

    @Test("setAlgorithm switches and restarts the layout")
    func switchesAlgorithm() {
        let orchestrator = LayoutOrchestrator(graph: Graph.smallGraph)
        for _ in 0..<10 { orchestrator.step() }
        orchestrator.setAlgorithm(.kamadaKawai)
        orchestrator.stop()
        #expect(orchestrator.config.algorithm == .kamadaKawai)
        #expect(orchestrator.iteration == 0)
        while !orchestrator.isSettled { orchestrator.step() }
        #expect(orchestrator.isSettled)

        orchestrator.setAlgorithm(.fruchtermanReingold)
        orchestrator.stop()
        #expect(orchestrator.iteration == 0)
        #expect(!orchestrator.isSettled)
    }

    /// gstudio's default 50·n moves leaves arapat still rearranging (R's own
    /// layout keeps moving between 50·n and 100·n moves), so the orchestrator
    /// should say so and suggest a budget that reaches rest.
    @Test("Arapat at R's default budget is flagged as still moving")
    func arapatNeedsMoreMoves() throws {
        let fixture = try #require(try loadCases()["arapat"])
        let o = LayoutOrchestrator(graph: fixture.graph, config: kkConfig())
        while !o.isSettled { o.step() }
        guard case .stoppedStillMoving(_, let suggested?) = o.settleOutcome else {
            Issue.record("expected a still-moving cut-off, got \(String(describing: o.settleOutcome))")
            return
        }
        #expect(suggested > 50)

        o.continueRun(toBudget: suggested)
        o.stop()
        while !o.isSettled { o.step() }
        #expect(o.settleOutcome == .atRest)
        #expect(o.iteration == suggested, "KK runs exactly its budget, one move per node per frame")
    }

    @Test("Lopho comes to rest within R's default budget")
    func lophoAtRest() {
        let o = LayoutOrchestrator(graph: Graph.lophoGraph, config: kkConfig())
        while !o.isSettled { o.step() }
        #expect(o.settleOutcome == .atRest)
    }

    @Test("A pinned node follows its target while the rest relaxes")
    func pinnedNodeFollowsTarget() {
        let orchestrator = LayoutOrchestrator(graph: Graph.lophoGraph, config: kkConfig())
        while !orchestrator.isSettled { orchestrator.step() }

        let target = SIMD3<Float>(400, 250, 0)
        orchestrator.pinNode(at: 2, position: target)
        orchestrator.stop()
        for _ in 0..<5 { orchestrator.step() }
        #expect(isApprox(orchestrator.state.positions[2].x, target.x, tolerance: 1e-3))
        #expect(isApprox(orchestrator.state.positions[2].y, target.y, tolerance: 1e-3))
        #expect(!orchestrator.isSettled)

        orchestrator.unpinNode(at: 2)
        orchestrator.stop()
        while !orchestrator.isSettled { orchestrator.step() }
        #expect(orchestrator.isSettled)
    }
}
