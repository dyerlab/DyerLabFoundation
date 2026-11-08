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
//  The ratio is always reported as Φ_ST, for one locus or many. A single
//  locus's AMOVA is not Weir & Cockerham's θ (it has no within-individual
//  level); that is `WeirCockerhamAnalysis`.
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
    ///   - tag: The label for the outcome (default `.amovaPhiST`).
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
        statisticLabel = "Φ_ST"
        unitLabel = "individuals"
        groupLabel = "strata"
    }
}

extension VarianceDecompositionOutcome {

    /// Φ_ST: the among/total variance ratio.
    public var phi: Double { statistic }
}
