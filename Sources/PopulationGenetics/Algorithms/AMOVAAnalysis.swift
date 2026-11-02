//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AMOVAAnalysis.swift
//  PopulationGenetics
//
//  Population genetics' names for Matrix's `VarianceDecompositionAnalysis`,
//  plus a constructor from individuals' genetic distances and stratum labels.
//  Multi-locus distances give Φ_ST; a single locus's distances give Weir &
//  Cockerham's θ — the same computation, so only the `tag` differs.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// AMOVA as an `Analysis`.
public typealias AMOVAAnalysis = VarianceDecompositionAnalysis

/// The outcome of an ``AMOVAAnalysis``.
public typealias AMOVAOutcome = VarianceDecompositionOutcome

extension VarianceDecompositionAnalysis {

    /// Builds an AMOVA from individuals' genetic distances and their strata.
    ///
    /// - Parameters:
    ///   - distance: Squared genetic distances among individuals.
    ///   - strata: Each individual's stratum, in `distance` order.
    ///   - tag: `.amovaPhiST` (default) for multi-locus distances, or
    ///     `.weirCockerhamTheta` for a single locus.
    /// - Returns: `nil` if `strata` is the wrong length, there are fewer than
    ///   two strata, or every stratum has a single individual.
    public init?(distance: GeneticDistanceMatrix, strata: [String], tag: AnalysisTag = .amovaPhiST) {
        var index: [String: Int] = [:]
        let partition = strata.map { label in
            if let i = index[label] { return i }
            index[label] = index.count
            return index.count - 1
        }
        self.init(squaredDistances: distance.dense(), partition: partition, tag: tag)
        statisticLabel = tag == .weirCockerhamTheta ? "θ" : "Φ_ST"
        unitLabel = "individuals"
        groupLabel = "strata"
    }
}

extension VarianceDecompositionOutcome {

    /// Φ_ST (or θ for a single locus): the among/total variance ratio.
    public var phi: Double { statistic }
}
