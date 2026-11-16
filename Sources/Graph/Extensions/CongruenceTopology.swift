//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  CongruenceTopology.swift
//  Graph
//
//  Direct ports of gstudio's `congruence_topology()` and `test_congruence()` —
//  the shared-edge topology of two graphs, and a Pearson correlation test
//  between their shortest-path distance structures.
//  See `~/Coding/gstudio/R/congruence_topology.R` and `test_congruence.R`.
//
//  Created by Rodney Dyer on 2026.09.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import Foundation

/// The congruence (shared-edge) topology of two graphs — a port of gstudio's
/// `congruence_topology()`.
///
/// The result contains the nodes present in **both** graphs (in `graph1`'s
/// order) and an unweighted, undirected edge for every pair connected in both.
///
/// Node attributes of both parents are carried over as gstudio 1.15 does: an attribute found in only one graph is
/// copied, one found in both with the same values on the shared nodes is copied once, and one whose values differ
/// is kept from both as `<name>.1` and `<name>.2`. Continuous values agree within R's `all.equal()` tolerance
/// (1.5 × 10⁻⁸, relative). Size, colour and coordinate come from `graph1` (the coordinate from `graph2` when
/// `graph1` has none); sizes that differ are also kept as the continuous attributes `size.1` and `size.2`.
///
/// Non-overlapping nodes are dropped silently (gstudio emits a warning); if the
/// two node sets differ, interpret the result with care.
///
/// - Parameters:
///   - graph1: The reference graph; node order and node properties come from it.
///   - graph2: The graph to intersect with.
/// - Returns: The shared-edge graph.
public func CongruenceTopology(_ graph1: Graph, _ graph2: Graph) -> Graph {
    let names2 = Set(graph2.nodes.map { $0.name })
    let common = graph1.nodes.map { $0.name }.filter { names2.contains($0) }
    let commonSet = Set(common)
    let adjacency2 = graph2.undirectedAdjacency()

    let first = common.map { graph1.node(name: $0) }
    let second = common.map { graph2.node(name: $0) }
    var continuous = mergedAttributes(first.map { $0?.continuousAttributes }, second.map { $0?.continuousAttributes },
                                      same: { a, b in abs(a - b) <= 1.5e-8 * max(abs(a), 1e-300) })
    let sizes1 = first.map { $0?.size }, sizes2 = second.map { $0?.size }
    if !zip(sizes1, sizes2).allSatisfy({ $0 == $1 }) {
        for i in common.indices {
            if let size = sizes1[i] { continuous[i]["size.1"] = size }
            if let size = sizes2[i] { continuous[i]["size.2"] = size }
        }
    }
    let categorical = mergedAttributes(first.map { $0?.categoricalAttributes },
                                       second.map { $0?.categoricalAttributes }, same: ==)

    let newNodes = common.indices.map { i -> Node in
        let source = first[i]
        let copy = Node(name: common[i], size: source?.size ?? 1.0, color: source?.color ?? .red,
                        categoricalAttributes: categorical[i], continuousAttributes: continuous[i])
        if let coordinate = source?.coordinate ?? second[i]?.coordinate { copy.coordinate = coordinate }
        return copy
    }
    let nodeByName = Dictionary(uniqueKeysWithValues: newNodes.map { ($0.name, $0) })

    var edges: [Edge] = []
    for edge in graph1.undirectedEdgeList()
    where commonSet.contains(edge.from) && commonSet.contains(edge.to) {
        guard adjacency2[edge.from]?[edge.to] != nil else { continue }
        guard let from = nodeByName[edge.from], let to = nodeByName[edge.to] else { continue }
        edges.append(Edge(fromNode: from, toNode: to, weight: 1.0))
    }

    return Graph(nodes: newNodes, edges: edges)
}

/// Merges two graphs' attributes on their shared nodes (see ``CongruenceTopology(_:_:)``).
///
/// - Parameters:
///   - first: Each shared node's attributes in the first graph.
///   - second: The same nodes' attributes in the second graph.
///   - same: Whether two values agree.
/// - Returns: Each shared node's merged attributes.
private func mergedAttributes<Value>(_ first: [[String: Value]?], _ second: [[String: Value]?],
                                     same: (Value, Value) -> Bool) -> [[String: Value]] {
    let keys1 = Set(first.flatMap { $0.map { Array($0.keys) } ?? [] })
    let keys2 = Set(second.flatMap { $0.map { Array($0.keys) } ?? [] })
    var merged = [[String: Value]](repeating: [:], count: first.count)
    for key in keys1.union(keys2) {
        let v1 = first.map { $0?[key] }, v2 = second.map { $0?[key] }
        let agree = zip(v1, v2).allSatisfy { a, b in
            switch (a, b) {
            case (nil, nil): true
            case let (a?, b?): same(a, b)
            default: false
            }
        }
        for i in merged.indices {
            if !keys2.contains(key) || agree {
                merged[i][key] = v1[i]
            } else if !keys1.contains(key) {
                merged[i][key] = v2[i]
            } else {
                merged[i]["\(key).1"] = v1[i]
                merged[i]["\(key).2"] = v2[i]
            }
        }
    }
    return merged
}

/// The result of ``TestCongruence(_:_:)``.
public struct CongruenceTest: Sendable, Equatable {
    /// Pearson correlation between the two graphs' pairwise shortest-path
    /// distances, over node pairs finite in both.
    public let correlation: Double
    /// The t statistic `r · √(df / (1 − r²))`.
    public let statistic: Double
    /// Degrees of freedom: (number of usable pairs) − 2.
    public let df: Int
    /// Two-sided p-value, matching R's `cor.test(method = "pearson")`.
    public let pValue: Double
    /// The number of node pairs used (those finite in both distance matrices).
    public let n: Int
}

/// Tests the distance congruence between two graphs — a port of gstudio's
/// `test_congruence()`.
///
/// Computes each graph's all-pairs shortest-path distance matrix over the nodes
/// they share, then correlates the lower-triangle distances (dropping any pair
/// unreachable in either graph) with a two-sided Pearson test.
///
/// - Parameters:
///   - graph1: The first graph.
///   - graph2: The second graph.
/// - Returns: A ``CongruenceTest``, or `nil` if the graphs share no nodes,
///   fewer than three node pairs are finite in both, or the correlation is
///   undefined (a constant distance vector).
public func TestCongruence(_ graph1: Graph, _ graph2: Graph) -> CongruenceTest? {
    let names2 = Set(graph2.nodes.map { $0.name })
    let common = graph1.nodes.map { $0.name }.filter { names2.contains($0) }
    guard common.count >= 3 else { return nil }

    let distance1 = graph1.inducedSubgraph(nodeNames: common).weightedDistanceMatrix()
    let distance2 = graph2.inducedSubgraph(nodeNames: common).weightedDistanceMatrix()

    // inducedSubgraph preserves `common` order, so both matrices are indexed
    // identically and the lower triangle lines up pair-for-pair.
    var d1: [Double] = []
    var d2: [Double] = []
    for i in 1..<common.count {
        for j in 0..<i {
            let a = distance1[i, j]
            let b = distance2[i, j]
            guard a.isFinite, b.isFinite else { continue }
            d1.append(a)
            d2.append(b)
        }
    }

    let n = d1.count
    guard n >= 3 else { return nil }

    let r = pearsonCorrelation(d1, d2)
    guard r.isFinite else { return nil }

    let df = Double(n - 2)
    let statistic = r * (df / (1.0 - r * r)).squareRoot()
    let pValue = studentTTwoSidedPValue(statistic, degreesOfFreedom: df)

    return CongruenceTest(correlation: r, statistic: statistic, df: n - 2, pValue: pValue, n: n)
}
