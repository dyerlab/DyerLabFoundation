//
//  CongruenceTopology.swift
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
//  Direct ports of gstudio's `congruence_topology()` and `test_congruence()` —
//  the shared-edge topology of two graphs, and a Pearson correlation test
//  between their shortest-path distance structures.
//  See `~/Coding/gstudio/R/congruence_topology.R` and `test_congruence.R`.
//

import Matrix
import Foundation

/// The congruence (shared-edge) topology of two graphs — a port of gstudio's
/// `congruence_topology()`.
///
/// The result contains the nodes present in **both** graphs (in `graph1`'s
/// order) and an unweighted, undirected edge for every pair connected in both.
/// Node sizes, colours, coordinates, and attributes are carried over from
/// `graph1`.
///
/// Non-overlapping nodes are dropped silently (gstudio emits a warning); if the
/// two node sets differ, interpret the result with care.
public func CongruenceTopology(_ graph1: Graph, _ graph2: Graph) -> Graph {
    let names2 = Set(graph2.nodes.map { $0.name })
    let common = graph1.nodes.map { $0.name }.filter { names2.contains($0) }
    let commonSet = Set(common)
    let adjacency2 = graph2.undirectedAdjacency()

    let newNodes = common.map { original -> Node in
        let source = graph1.node(name: original)
        let copy = Node(name: original, size: source?.size ?? 1.0, color: source?.color ?? .red,
                        categoricalAttributes: source?.categoricalAttributes ?? [:],
                        continuousAttributes: source?.continuousAttributes ?? [:])
        if let coordinate = source?.coordinate { copy.coordinate = coordinate }
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
