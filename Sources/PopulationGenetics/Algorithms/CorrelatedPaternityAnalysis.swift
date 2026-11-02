//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  CorrelatedPaternityAnalysis.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// Correlated-paternity estimation from maternal families
/// (`AnalysisType.correlatedPaternity`).
public struct CorrelatedPaternityAnalysis: Analysis {

    /// `AnalysisType.correlatedPaternity`.
    public static let analysisType: AnalysisType = .correlatedPaternity

    /// The genotypes of mothers and offspring.
    public let matrix: GenotypeMatrix

    /// The maternal families.
    public let design: ParentageDesign

    /// Creates the analysis.
    ///
    /// - Parameters:
    ///   - matrix: The genotypes of mothers and offspring.
    ///   - design: The maternal families.
    /// - Returns: `nil` if `design` has no families.
    public init?(matrix: GenotypeMatrix, design: ParentageDesign) {
        guard !design.families.isEmpty else { return nil }
        self.matrix = matrix
        self.design = design
    }

    /// Estimates `r_p` pooled over families.
    ///
    /// - Parameter options: Not used; the estimator is deterministic.
    /// - Returns: The estimate, or `nil` if no sib pair was informative.
    public func run(options: AnalysisOptions) -> CorrelatedPaternity? {
        let estimate = matrix.correlatedPaternity(design: design)
        return estimate.informativePairCount > 0 ? estimate : nil
    }
}
