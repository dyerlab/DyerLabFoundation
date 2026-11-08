//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IBDAnalysis.swift
//  PopulationGenetics
//
//  Isolation by distance: the spec's genetic distances against great-circle
//  distance among the units both matrices hold, with a Mantel test (Mantel
//  1967) whose permutations are gstudio's for the same seed. Pairwise Φ_ST
//  can be linearized as Φ_ST / (1 − Φ_ST) (Rousset 1997), which uses
//  `IsolationByDistanceAnalysis` and its wording; any other measure is a
//  plain `MantelAnalysis`. Pairs with a non-finite genetic distance (Φ_ST ≥ 1
//  linearized, or no locus in common) are left out of the test.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix

/// An isolation-by-distance analysis of a dataset, ready to run.
public struct IBDAnalysis: Sendable {

    /// Why an analysis can't be made.
    public enum Failure: Error, Equatable, LocalizedError {
        /// The spec's genetic measure doesn't work at its level, or the level has too few genotyped units.
        case noGeneticDistances
        /// Fewer than three of the units have both genotypes and coordinates.
        case tooFewLocatedUnits
        /// Some units share a location, whose distance of 0 km has no logarithm.
        case sharedLocations
        /// Fewer than three pairs have a finite genetic distance.
        case tooFewPairs

        /// What went wrong, for an alert or an empty page.
        public var errorDescription: String? {
            switch self {
            case .noGeneticDistances:
                "This genetic distance can't be computed here: there are too few genotyped units."
            case .tooFewLocatedUnits:
                "Fewer than three units have both genotypes and coordinates."
            case .sharedLocations:
                "Some units share a location, and a distance of 0 km has no logarithm. Turn off ln distance."
            case .tooFewPairs:
                "Fewer than three pairs have a finite genetic distance to test."
            }
        }
    }

    /// The test, in one of its two wordings.
    private enum Test: Sendable {
        /// Rousset's linearized Φ_ST.
        case rousset(IsolationByDistanceAnalysis)
        /// Any genetic distance as it is.
        case mantel(MantelAnalysis)
    }

    /// What is tested.
    public let spec: IBDSpec
    /// Whether the adults are the mothers of parent/offspring data.
    public let isParentOffspring: Bool
    /// The units tested, in the genetic matrix's order.
    public let names: [String]
    /// The genetic units left out because they have no coordinates.
    public let unlocated: [String]
    private let test: Test

    // MARK: - Initialization

    /// Computes the two matrices and prepares the test.
    ///
    /// - Parameters:
    ///   - spec: What to test; its test and result are ignored until ``run(observing:)``.
    ///   - dataset: The genotypes, with their coordinates and strata.
    /// - Throws: A ``Failure`` saying why the data can't support the test.
    public init(spec: IBDSpec, dataset: ImportedDataset) throws(Failure) {
        guard spec.genetic.measure.isGenetic,
              let genetic = DistanceAnalysis(spec: spec.genetic, dataset: dataset)?.run() else {
            throw .noGeneticDistances
        }
        guard let separation = DistanceAnalysis(spec: spec.separation, dataset: dataset)?.run() else {
            throw .tooFewLocatedUnits
        }
        let located = Set(separation.matrix.groupNames)
        let names = genetic.matrix.groupNames.filter(located.contains)
        guard names.count >= 3 else { throw .tooFewLocatedUnits }
        let geneticMatrix = Self.restricted(genetic.matrix, to: names)
        let separationMatrix = Self.restricted(separation.matrix, to: names)
        if spec.logSeparation, separationMatrix.dense().enumerated().contains(where: { i, row in
            row.enumerated().contains { j, d in i != j && d <= 0 }
        }) {
            throw .sharedLocations
        }

        self.spec = spec
        self.isParentOffspring = !dataset.parentage.families.isEmpty
        self.names = names
        self.unlocated = genetic.matrix.groupNames.filter { !located.contains($0) }
        let unitLabel = spec.genetic.isAmongIndividuals
            ? spec.genetic.unitName(isParentOffspring: isParentOffspring) : "\(spec.genetic.level) strata"
        switch spec.validTransform {
        case .rousset:
            guard let analysis = IsolationByDistanceAnalysis(differentiation: geneticMatrix,
                                                             separation: separationMatrix,
                                                             logSeparation: spec.logSeparation,
                                                             differentiationLabel: "Φ_ST",
                                                             separationLabel: "great-circle distance (km)",
                                                             method: spec.method) else { throw .tooFewPairs }
            test = .rousset(analysis)
        case .none:
            let response = geneticMatrix.dense()
            let predictor = separationMatrix.dense().map { row in
                row.map { spec.logSeparation && $0 > 0 ? Foundation.log($0) : $0 }
            }
            guard var mantel = MantelAnalysis(response: response, predictor: predictor, names: names,
                                              method: spec.method) else { throw .tooFewPairs }
            mantel.responseLabel = spec.genetic.measure.title
            mantel.predictorLabel = (spec.logSeparation ? "the natural log of " : "") + "great-circle distance (km)"
            mantel.unitLabel = unitLabel
            test = .mantel(mantel)
        }
    }

    /// A matrix among some of its units, in the order given.
    private static func restricted(_ matrix: UnitDistanceMatrix, to names: [String]) -> UnitDistanceMatrix {
        var restricted = UnitDistanceMatrix(groupNames: names)
        for i in names.indices {
            for j in (i + 1)..<names.count { restricted[i, j] = matrix[names[i], names[j]] ?? .nan }
        }
        return restricted
    }

    // MARK: - Running

    /// Runs the test with the spec's permutations and seed, reporting each permuted correlation.
    ///
    /// - Parameter observing: Called after each permutation with the number done and the permuted correlation;
    ///   return `false` to stop.
    /// - Returns: The result, or `nil` if `observing` stopped the test.
    public func run(observing: (_ done: Int, _ value: Double) -> Bool = { _, _ in true }) -> IBDResult? {
        let options = AnalysisOptions(iterations: spec.isTested ? spec.permutations : 0, seed: spec.seed ?? 0)
        let outcome: MantelOutcome
        let report: AnalysisReport
        switch test {
        case .rousset(let analysis):
            guard let ibd = analysis.run(options: options, observing: observing) else { return nil }
            outcome = ibd.mantel
            report = analysis.report(for: ibd, options: options)
        case .mantel(let analysis):
            guard let mantel = analysis.run(options: options, observing: observing) else { return nil }
            outcome = mantel
            report = analysis.report(for: mantel, options: options)
        }
        let x = outcome.points.map(\.x)
        let y = outcome.points.map(\.y)
        let pearson = pearsonCorrelation(x, y)
        var spec = spec
        spec.result = IBDSpec.Summary(r: outcome.r, p: outcome.distribution?.pValue(),
                                      slope: outcome.line?.slope, intercept: outcome.line?.intercept,
                                      r2: pearson.isFinite ? pearson * pearson : nil, pairs: outcome.pairCount)
        return IBDResult(spec: spec, outcome: outcome, report: report, isParentOffspring: isParentOffspring,
                         unlocated: unlocated)
    }
}
