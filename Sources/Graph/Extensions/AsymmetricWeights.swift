//
//  AsymmetricWeights.swift
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
//  Direct ports of gstudio's `asymmetric_weights()` and `asymmetric_popgraph()`
//  — a t-SNE-inspired local embedding that splits each undirected conditional
//  genetic distance into its two directional shares. See
//  `~/Coding/gstudio/R/asymmetric_weights.R` and `asymmetric_popgraph.R`.
//

import Matrix
import Foundation

/// One undirected edge's directional decomposition, from
/// ``AsymmetricWeights(graph:perplexity:tolerance:maxIterations:)``.
public struct AsymmetricWeight: Sendable, Equatable {
    /// First endpoint (``Graph/undirectedEdgeList()`` order).
    public let i: String
    /// Second endpoint.
    public let j: String
    /// `p_{j|i}`: conditional probability of `j` given `i`, normalised across
    /// `i`'s neighbours.
    public let pij: Double
    /// `p_{i|j}`: conditional probability of `i` given `j`.
    public let pji: Double
    /// The conditional genetic distance (edge weight) from the input graph.
    public let cGD: Double
    /// Share of `cGD` allocated in the `i → j` direction: `cGD · pij / (pij + pji)`.
    public let dij: Double
    /// Share of `cGD` allocated in the `j → i` direction.
    public let dji: Double
    /// Directional bias `dij − dji` (positive favours `i → j`).
    public let delta: Double
}

/// Estimates asymmetric (directional) edge weights for an undirected population
/// graph — a port of gstudio's `asymmetric_weights()`.
///
/// For each node a per-node Gaussian bandwidth `σ` is found by binary search so
/// the neighbourhood distribution hits `perplexity`; the resulting conditional
/// probabilities partition every edge's weight `cGD` into directional shares
/// `dij`/`dji` with `dij + dji == cGD`, so total graph distance is preserved.
///
/// - Parameters:
///   - graph: An undirected, weighted graph.
///   - perplexity: Target perplexity for the per-node bandwidth search (default `4`).
///   - tolerance: Convergence tolerance on the perplexity match (default `1e-5`).
///   - maxIterations: Maximum bandwidth binary-search iterations (default `100`).
/// - Returns: One ``AsymmetricWeight`` per undirected edge, in
///   ``Graph/undirectedEdgeList()`` order.
public func AsymmetricWeights(graph: Graph,
                              perplexity: Double = 4,
                              tolerance: Double = 1e-5,
                              maxIterations: Int = 100) -> [AsymmetricWeight] {

    let names = graph.nodes.map { $0.name }
    let adjacency = graph.undirectedAdjacency()

    // Directed conditional-probability lookup: prob[i][j] = p_{j|i}.
    var prob: [String: [String: Double]] = [:]
    for name in names {
        let neighbors = adjacency[name] ?? [:]
        guard !neighbors.isEmpty else { continue }

        let neighborNames = Array(neighbors.keys)
        let distances = neighborNames.map { neighbors[$0]! }

        let p: [Double]
        if distances.count == 1 {
            p = [1.0]
        } else {
            let sigma = findSigma(distances: distances,
                                  targetPerplexity: perplexity,
                                  tolerance: tolerance,
                                  maxIterations: maxIterations)
            let raw = distances.map { exp(-($0 * $0) / (2.0 * sigma * sigma)) }
            let total = raw.reduce(0, +)
            p = raw.map { $0 / total }
        }

        var row: [String: Double] = [:]
        for (index, neighbor) in neighborNames.enumerated() {
            row[neighbor] = p[index]
        }
        prob[name] = row
    }

    return graph.undirectedEdgeList().map { edge -> AsymmetricWeight in
        let cGD = edge.weight
        let pij = prob[edge.from]?[edge.to] ?? 0.0
        let pji = prob[edge.to]?[edge.from] ?? 0.0
        let sum = pij + pji
        let dij = cGD * pij / sum
        let dji = cGD * pji / sum
        return AsymmetricWeight(i: edge.from, j: edge.to,
                                pij: pij, pji: pji, cGD: cGD,
                                dij: dij, dji: dji, delta: dij - dji)
    }
}

/// Converts an undirected population graph into a directed one whose edge
/// weights are the directional partial distances from
/// ``AsymmetricWeights(graph:perplexity:tolerance:maxIterations:)`` — a port of
/// gstudio's `asymmetric_popgraph()`.
///
/// Each undirected edge `(i, j)` becomes two directed edges: `i → j` with
/// weight `dij` and `j → i` with weight `dji`. Node names, sizes, colours,
/// coordinates, and attributes are carried over. The total edge weight of the
/// result equals the total conditional genetic distance of the input.
///
/// - Parameters:
///   - graph: An undirected, weighted graph.
///   - perplexity: Target perplexity for the per-node bandwidth search (default `4`).
///   - tolerance: Convergence tolerance on the perplexity match (default `1e-5`).
///   - maxIterations: Maximum bandwidth binary-search iterations (default `100`).
/// - Returns: A directed graph with twice as many edges as the input.
public func AsymmetricPopulationGraph(graph: Graph,
                                      perplexity: Double = 4,
                                      tolerance: Double = 1e-5,
                                      maxIterations: Int = 100) -> Graph {

    let weights = AsymmetricWeights(graph: graph,
                                    perplexity: perplexity,
                                    tolerance: tolerance,
                                    maxIterations: maxIterations)

    let newNodes = graph.nodes.map { source -> Node in
        let copy = Node(name: source.name, size: source.size, color: source.color,
                        categoricalAttributes: source.categoricalAttributes,
                        continuousAttributes: source.continuousAttributes)
        if let coordinate = source.coordinate { copy.coordinate = coordinate }
        return copy
    }
    let nodeByName = Dictionary(uniqueKeysWithValues: newNodes.map { ($0.name, $0) })

    var edges: [Edge] = []
    for weight in weights {
        guard let from = nodeByName[weight.i], let to = nodeByName[weight.j] else { continue }
        edges.append(Edge(fromNode: from, toNode: to, weight: weight.dij))
        edges.append(Edge(fromNode: to, toNode: from, weight: weight.dji))
    }

    return Graph(nodes: newNodes, edges: edges)
}

// MARK: - Bandwidth search

/// Shannon entropy `−Σ p·log₂ p` over the positive entries of `p`.
private func shannonEntropy(_ p: [Double]) -> Double {
    -p.reduce(0.0) { partial, value in
        value > 0 ? partial + value * log2(value) : partial
    }
}

/// Binary search for the Gaussian bandwidth `σ` whose neighbourhood
/// distribution has perplexity `targetPerplexity`. A direct port of the
/// `find_sigma()` closure inside gstudio's `asymmetric_weights()`: bounded
/// search on `σ ∈ [1e-6, 10]`, returning the last midpoint evaluated.
private func findSigma(distances: [Double],
                       targetPerplexity: Double,
                       tolerance: Double,
                       maxIterations: Int) -> Double {
    if distances.count == 1 { return 1e-3 }

    var sigmaMin = 1e-6
    var sigmaMax = 10.0
    var sigma = (sigmaMin + sigmaMax) / 2.0

    for _ in 0..<maxIterations {
        sigma = (sigmaMin + sigmaMax) / 2.0
        let raw = distances.map { exp(-($0 * $0) / (2.0 * sigma * sigma)) }
        let total = raw.reduce(0, +)
        let p = raw.map { $0 / total }
        let perplexity = pow(2.0, shannonEntropy(p))
        if abs(perplexity - targetPerplexity) < tolerance { break }
        if perplexity > targetPerplexity {
            sigmaMax = sigma
        } else {
            sigmaMin = sigma
        }
    }

    return sigma
}
