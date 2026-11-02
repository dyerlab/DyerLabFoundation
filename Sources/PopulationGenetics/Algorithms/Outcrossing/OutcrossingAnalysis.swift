//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  OutcrossingAnalysis.swift
//  PopulationGenetics
//
//  The `Analysis` front end for the `Outcrossing` sampler. The chain's own
//  length settings stay in `Outcrossing.Parameters` (MCMC steps are not
//  resampling iterations); only the seed comes from `AnalysisOptions`, so
//  every analysis is reproduced the same way.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// Outcrossing-rate estimation from maternal families (`AnalysisType.outcrossing`).
public struct OutcrossingAnalysis: Analysis {

    /// `AnalysisType.outcrossing`.
    public static let analysisType: AnalysisType = .outcrossing

    /// The genotypes of mothers and offspring.
    public let matrix: GenotypeMatrix

    /// The maternal families.
    public let design: ParentageDesign

    /// Chain settings; `seed` is replaced by `AnalysisOptions.seed` at run time.
    public let parameters: Outcrossing.Parameters

    /// Per-locus null-allele flags, in `matrix.loci` order, or `nil` for none.
    public let hasNullModel: [Bool]?

    /// The single locus to analyse (`t_s`), or `nil` for all loci jointly (`t_m`).
    public let locus: Int?

    /// Creates the analysis.
    ///
    /// - Parameters:
    ///   - matrix: The genotypes of mothers and offspring.
    ///   - design: The maternal families.
    ///   - parameters: Chain settings (default `Outcrossing.Parameters()`).
    ///   - hasNullModel: Per-locus null-allele flags, or `nil` for none.
    ///   - locus: One locus index for a single-locus estimate, or `nil` (default)
    ///     for the multilocus estimate.
    /// - Returns: `nil` if `design` has no families, `hasNullModel` is not one
    ///   flag per locus, or `locus` is out of range.
    public init?(matrix: GenotypeMatrix,
                 design: ParentageDesign,
                 parameters: Outcrossing.Parameters = Outcrossing.Parameters(),
                 hasNullModel: [Bool]? = nil,
                 locus: Int? = nil) {
        guard !design.families.isEmpty,
              hasNullModel.map({ $0.count == matrix.locusCount }) ?? true,
              locus.map({ (0..<matrix.locusCount).contains($0) }) ?? true else { return nil }
        self.matrix = matrix
        self.design = design
        self.parameters = parameters
        self.hasNullModel = hasNullModel
        self.locus = locus
    }

    /// Runs the chain.
    ///
    /// - Parameter options: The seed; `iterations` is not used.
    /// - Returns: The retained posterior samples, or `nil` if the chain kept none.
    public func run(options: AnalysisOptions) -> Outcrossing.Result? {
        var parameters = parameters
        parameters.seed = options.seed
        let result = if let locus {
            matrix.runOutcrossing(atLocus: locus, design: design, parameters: parameters, hasNullModel: hasNullModel)
        } else {
            matrix.runOutcrossing(design: design, parameters: parameters, hasNullModel: hasNullModel)
        }
        return result.samples.isEmpty ? nil : result
    }
}
