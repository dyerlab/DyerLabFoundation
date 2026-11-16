//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GravityCongruenceOutcome.swift
//  Graph
//
//  The result of a `GravityCongruenceAnalysis`: gstudio's gravity_congruence()
//  `tests`, `nodes` and `edges` tables.
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// The agreement of two graphs' genetic gravity: source-sink scores and edge direction.
public struct GravityCongruenceOutcome: AnalysisOutcome {

    /// The label this outcome was produced under.
    public let tag: AnalysisTag

    /// Spearman's ρ between the two graphs' source-sink scores, `NaN` when either set of scores is constant.
    public let rho: Double

    /// The label-permutation null of ρ, or `nil` if not tested.
    public let distribution: NullDistributionResult?

    /// The populations, with their scores in both graphs.
    public let nodes: [GravityCongruenceNode]

    /// The edges in both graphs.
    public let edges: [GravityCongruenceEdge]

    /// The shared edges along which gene flow runs the same way in both graphs.
    public let concordantEdges: Int

    /// The shared edges with a direction in both graphs (Δ ≠ 0).
    public let directedEdges: Int

    /// The one-sided exact binomial P of ``concordantEdges`` against ½, or `nil` with no directed edges.
    public let edgePValue: Double?

    /// Always `AnalysisType.gravityCongruence`.
    public var analysisType: AnalysisType { .gravityCongruence }

    /// ρ, ``rho``.
    public var statistic: Double { rho }

    /// The share of directed shared edges that agree, or `nil` with none.
    public var edgeConcordance: Double? {
        directedEdges > 0 ? Double(concordantEdges) / Double(directedEdges) : nil
    }

    /// gstudio's one-sided permutation P for ρ, `(1 + #{ρ_null ≥ ρ_obs − 10⁻¹²}) / (1 + #{finite ρ_null})`, or
    /// `nil` when untested or ρ is undefined.
    public var pValue: Double? {
        guard let values = distribution?.values, rho.isFinite else { return nil }
        let finite = values.filter(\.isFinite)
        return Double(1 + finite.filter { $0 >= rho - 1e-12 }.count) / Double(1 + finite.count)
    }

    /// Creates an outcome.
    ///
    /// - Parameters:
    ///   - tag: The label.
    ///   - rho: Spearman's ρ between the scores.
    ///   - distribution: Its permutation null, or `nil`.
    ///   - nodes: The populations.
    ///   - edges: The shared edges.
    ///   - concordantEdges: The shared edges that agree in direction.
    ///   - directedEdges: The shared edges with a direction in both graphs.
    ///   - edgePValue: The sign test's P, or `nil`.
    public init(tag: AnalysisTag, rho: Double, distribution: NullDistributionResult?, nodes: [GravityCongruenceNode],
                edges: [GravityCongruenceEdge], concordantEdges: Int, directedEdges: Int, edgePValue: Double?) {
        self.tag = tag
        self.rho = rho
        self.distribution = distribution
        self.nodes = nodes
        self.edges = edges
        self.concordantEdges = concordantEdges
        self.directedEdges = directedEdges
        self.edgePValue = edgePValue
    }
}
