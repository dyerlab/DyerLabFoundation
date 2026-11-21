//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DirectionalConditionalGeneticDistance.swift
//  PopulationGenetics
//
//  A port of gstudio's `genetic_distance(mode = "dcGD")` (internally
//  `dist_dcgd()`): directional conditional genetic distance among strata, built
//  from genotypes via the Population Graph. The graph-level computation is
//  Graph's `DirectionalConditionalGeneticDistance(graph:gamma:)`. See
//  `~/Coding/gstudio/R/dist_dcgd.R`.
//
//  Created by Rodney Dyer on 2026.10.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import Graph
import Foundation

/// Directional conditional genetic distance among strata from genotypes — a
/// port of gstudio's `genetic_distance(mode = "dcGD")`.
///
/// Builds the Population Graph (``PopulationGraph(x:groups:alpha:tol:)`` at its
/// defaults, as `dist_dcgd()` calls `popgraph()`), splits each edge's
/// conditional genetic distance into directed shares by the genetic-gravity
/// neighbourhood weights, and returns all-pairs directed shortest-path
/// distances. The result is asymmetric: `[i, j]` is the distance from `i` to
/// `j`, shorter in the direction of gene flow.
///
/// - Parameters:
///   - data: An N×P multivariate genotype matrix (e.g.
///     `GenotypeMatrix.multivariateMatrix()`, R's `to_mv()`).
///   - groups: The stratum label for each of `data`'s rows.
///   - gamma: Bandwidth multiplier (default `0.5`, degree-neutral).
/// - Returns: A `K × K` matrix over the strata (row/column names = graph node
///   order), `.infinity` for strata in different graph components, or `nil` if
///   the Population Graph cannot be built or `gamma` is not positive.
public func DirectionalConditionalGeneticDistance(data: Matrix, groups: [String], gamma: Double = 0.5) -> Matrix? {
    guard let graph = PopulationGraph(x: data, groups: groups) else { return nil }
    return DirectionalConditionalGeneticDistance(graph: graph, gamma: gamma)
}
