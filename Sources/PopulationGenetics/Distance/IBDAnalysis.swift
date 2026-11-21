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
//  Isolation by distance, gstudio's `genetic_isolation()`: the spec's genetic
//  distances against separation among the units both hold, with a Mantel test
//  (Mantel 1967) whose permutations are gstudio's for the same seed. Pairwise
//  Φ_ST can be linearized as Φ_ST / (1 − Φ_ST) (Rousset 1997), which uses
//  `IsolationByDistanceAnalysis` and its wording; any other measure is a plain
//  `MantelAnalysis`. Pairs with a non-finite genetic distance (Φ_ST ≥ 1
//  linearized, or no locus in common) are left out of the test.
//
//  cGD against geographic separation is isolation by graph distance and dcGD is
//  directional isolation by graph distance, as `genetic_isolation(mode = "IBGD")`
//  and `mode = "dcGD"` hand the population graph to `ibgd()`: both run Graph's
//  `IsolationByGraphDistanceAnalysis` on the graph, in its node order, and dcGD
//  then fits `DirectionalIsolationByGraphDistanceAnalysis`, the forward direction
//  coming from the spec's axis. Strata without a separation are left out of the
//  fits, though paths between the others still pass through them.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Graph
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
        /// The genetic distances would be tested against themselves.
        case sameMatrices
        /// dcGD needs an axis to say which way is forward.
        case needsAxis
        /// A directed measure (dcGD) can't be what genetic distances are tested against.
        case directedSeparation

        /// What went wrong, for an alert or an empty page.
        public var errorDescription: String? {
            switch self {
            case .noGeneticDistances:
                "This genetic distance can't be computed here: there are too few genotyped units."
            case .tooFewLocatedUnits:
                "Fewer than three units have both genotypes and coordinates."
            case .sharedLocations:
                "Some pairs are at a distance of 0, which has no logarithm. Turn off ln distance."
            case .tooFewPairs:
                "Fewer than three pairs have a finite genetic distance to test."
            case .sameMatrices:
                "A distance can't be tested against itself. Choose a different matrix to test against."
            case .needsAxis:
                "Directional conditional genetic distance needs an axis, such as latitude, to say which way is forward."
            case .directedSeparation:
                "Directional conditional genetic distance can only be the genetic distance, not what it is tested "
                    + "against."
            }
        }
    }

    /// The test, in one of its wordings.
    private enum Test: Sendable {
        /// Rousset's linearized Φ_ST.
        case rousset(IsolationByDistanceAnalysis)
        /// Any genetic distance as it is.
        case mantel(MantelAnalysis)
        /// cGD through the population graph, and for dcGD the directional fit.
        case graph(IsolationByGraphDistanceAnalysis, directional: DirectionalIsolationByGraphDistanceAnalysis?)
    }

    /// What is tested.
    public let spec: IBDSpec
    /// Whether the adults are the mothers of parent/offspring data.
    public let isParentOffspring: Bool
    /// The units tested, in the genetic matrix's order (for cGD and dcGD, the population graph's).
    public let names: [String]
    /// The genetic units left out because they have no coordinates or position on the axis.
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
        guard spec.genetic.measure.isGenetic else { throw .noGeneticDistances }
        if !spec.alongAxis {
            guard !spec.against.isDirected else { throw .directedSeparation }
            guard spec.against != spec.genetic.measure, !(spec.isDirectional && spec.against == .cgd) else {
                throw .sameMatrices
            }
        }
        guard !spec.isDirectional || spec.axis != nil else { throw .needsAxis }
        self.spec = spec
        self.isParentOffspring = !dataset.parentage.families.isEmpty
        let level = spec.genetic.level
        let positions = spec.axis.map { Self.positions(along: $0, at: level, in: dataset) }
        let unitLabel = spec.genetic.isAmongIndividuals
            ? spec.genetic.unitName(isParentOffspring: isParentOffspring) : "\(level) strata"

        // Isolation by graph distance and its directional form work on the population graph itself.
        if spec.isDirectional || (spec.genetic.measure == .cgd && spec.isGeographic) {
            guard let graph = DistanceAnalysis(spec: DistanceSpec(measure: .cgd, level: level),
                                               dataset: dataset)?.populationGraph() else { throw .noGeneticDistances }
            let nodes = graph.nodes.map(\.name)
            let separation = try Self.separation(spec, among: nodes, positions: positions, dataset: dataset)
            let placed = nodes.filter { separation.located.contains($0) && (!spec.isDirectional || positions?[$0] != nil) }
            guard placed.count >= 3 else { throw .tooFewLocatedUnits }
            let isPlaced = Set(placed)
            let X = Self.namedMatrix(nodes) { i, j in
                isPlaced.contains(nodes[i]) && isPlaced.contains(nodes[j]) ? separation.distance(nodes[i], nodes[j]) : .nan
            }
            let label = spec.separationLabel
            guard let ibgd = IsolationByGraphDistanceAnalysis(graph: graph, separation: .distances(X, forward: nil),
                                                              separationLabel: label, method: spec.method) else {
                throw .tooFewPairs
            }
            var directional: DirectionalIsolationByGraphDistanceAnalysis?
            if spec.isDirectional, let positions {
                let forward = Self.namedMatrix(nodes) { i, j in
                    guard let a = positions[nodes[i]], let b = positions[nodes[j]] else { return 0 }
                    return b > a ? 1 : 0
                }
                guard let analysis = DirectionalIsolationByGraphDistanceAnalysis(
                    graph: graph, separation: .distances(X, forward: forward), gamma: spec.gamma,
                    separationLabel: label) else { throw .tooFewPairs }
                directional = analysis
            }
            self.names = placed
            self.unlocated = nodes.filter { !isPlaced.contains($0) }
            self.test = .graph(ibgd, directional: directional)
            return
        }

        guard let genetic = DistanceAnalysis(spec: spec.genetic, dataset: dataset)?.run() else {
            throw .noGeneticDistances
        }
        let separation = try Self.separation(spec, among: genetic.matrix.groupNames, positions: positions,
                                             dataset: dataset)
        let names = genetic.matrix.groupNames.filter(separation.located.contains)
        guard names.count >= 3 else { throw .tooFewLocatedUnits }
        let geneticMatrix = Self.restricted(genetic.matrix, to: names)
        var separationMatrix = UnitDistanceMatrix(groupNames: names)
        for i in names.indices {
            for j in (i + 1)..<names.count { separationMatrix[i, j] = separation.distance(names[i], names[j]) }
        }
        self.names = names
        self.unlocated = genetic.matrix.groupNames.filter { !separation.located.contains($0) }
        switch spec.validTransform {
        case .rousset:
            guard let analysis = IsolationByDistanceAnalysis(differentiation: geneticMatrix,
                                                             separation: separationMatrix,
                                                             logSeparation: spec.logSeparation,
                                                             differentiationLabel: "Φ_ST",
                                                             separationLabel: spec.separationPhrase,
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
            mantel.predictorLabel = (spec.logSeparation ? "the natural log of " : "") + spec.separationPhrase
            mantel.unitLabel = unitLabel
            test = .mantel(mantel)
        }
    }

    /// The separation among some units: the difference along the spec's axis, or its `against` matrix. The Rousset
    /// and Mantel tests log-transform it themselves; for the graph tests it is logged here.
    ///
    /// - Parameters:
    ///   - spec: The analysis.
    ///   - names: The units.
    ///   - positions: The units' positions along the spec's axis, if it has one.
    ///   - dataset: The genotypes, with their coordinates and strata.
    /// - Returns: The units that have a separation, and the distance between two of them.
    /// - Throws: ``Failure/tooFewLocatedUnits`` without the matrix, or ``Failure/sharedLocations`` when a logged
    ///   separation would be zero.
    private static func separation(_ spec: IBDSpec, among names: [String], positions: [String: Double]?,
                                   dataset: ImportedDataset) throws(Failure)
        -> (located: Set<String>, distance: (String, String) -> Double) {
        let isGraph = spec.isDirectional || spec.genetic.measure == .cgd && spec.isGeographic
        let located: Set<String>
        let raw: (String, String) -> Double
        if spec.alongAxis, let positions {
            located = Set(names.filter { positions[$0] != nil })
            raw = { a, b in abs((positions[b] ?? .nan) - (positions[a] ?? .nan)) }
        } else {
            guard let result = DistanceAnalysis(spec: spec.separation, dataset: dataset)?.run() else {
                throw .tooFewLocatedUnits
            }
            located = Set(result.matrix.groupNames)
            raw = { a, b in result.matrix[a, b] ?? .nan }
        }
        if spec.logSeparation {
            let kept = names.filter(located.contains)
            for (i, a) in kept.enumerated() {
                for b in kept[(i + 1)...] where raw(a, b) <= 0 { throw .sharedLocations }
            }
        }
        guard isGraph, spec.logSeparation else { return (located, raw) }
        return (located, { a, b in Foundation.log(raw(a, b)) })
    }

    /// Each unit's position along an axis.
    ///
    /// - Parameters:
    ///   - axis: The axis.
    ///   - level: The units' level.
    ///   - dataset: The genotypes, with their coordinates and strata.
    /// - Returns: The positions of the units that have one, by name.
    private static func positions(along axis: IBDSpec.Axis, at level: String,
                                  in dataset: ImportedDataset) -> [String: Double] {
        switch axis.source {
        case .latitude: DistanceAnalysis.meanCoordinates(at: level, in: dataset).mapValues(\.latitude)
        case .longitude: DistanceAnalysis.meanCoordinates(at: level, in: dataset).mapValues(\.longitude)
        case .positions: (axis.positions ?? [:]).filter { $0.value.isFinite }
        }
    }

    /// A square matrix among named units, with the units as its row and column names.
    ///
    /// - Parameters:
    ///   - names: The units.
    ///   - value: The entry for row `i` and column `j`.
    /// - Returns: The matrix.
    private static func namedMatrix(_ names: [String], _ value: (Int, Int) -> Double) -> Matrix {
        let matrix = Matrix(names.count, names.count, 0.0)
        matrix.rowNames = names
        matrix.colNames = names
        for i in names.indices {
            for j in names.indices where i != j { matrix[i, j] = value(i, j) }
        }
        return matrix
    }

    /// A matrix among some of its units, in the order given.
    ///
    /// - Parameters:
    ///   - matrix: The full matrix.
    ///   - names: The units to keep, in order.
    /// - Returns: The matrix among `names`.
    private static func restricted(_ matrix: UnitDistanceMatrix, to names: [String]) -> UnitDistanceMatrix {
        var restricted = UnitDistanceMatrix(groupNames: names)
        for i in names.indices {
            for j in (i + 1)..<names.count { restricted[i, j] = matrix[names[i], names[j]] ?? .nan }
        }
        return restricted
    }

    // MARK: - Running

    /// Runs the test with the spec's permutations and seed, reporting each permuted correlation, then for dcGD the
    /// directional fit.
    ///
    /// - Parameter observing: Called after each permutation with the number done and the permuted correlation;
    ///   return `false` to stop.
    /// - Returns: The result; a test that `observing` stopped is finished with the permutations it drew, which its
    ///   spec and report state.
    public func run(observing: (_ done: Int, _ value: Double) -> Bool = { _, _ in true }) -> IBDResult? {
        let options = AnalysisOptions(iterations: spec.isTested ? spec.permutations : 0, seed: spec.seed ?? 0)
        var spec = spec
        /// The options as the test finished: with the permutations drawn, if it stopped short.
        func finished(_ outcome: MantelOutcome) -> AnalysisOptions {
            guard let drawn = outcome.distribution?.values.count, drawn < options.iterations else { return options }
            spec.permutations = drawn
            return AnalysisOptions(iterations: drawn, seed: options.seed)
        }
        let outcome: MantelOutcome
        var report: AnalysisReport
        var directionalOutcome: DirectionalIsolationByGraphDistanceOutcome?
        switch test {
        case .rousset(let analysis):
            guard let ibd = analysis.run(options: options, observing: observing) else { return nil }
            outcome = ibd.mantel
            report = analysis.report(for: ibd, options: finished(outcome))
        case .mantel(let analysis):
            guard let mantel = analysis.run(options: options, observing: observing) else { return nil }
            outcome = mantel
            report = analysis.report(for: mantel, options: finished(outcome))
        case .graph(let analysis, let directional):
            guard let ibgd = analysis.run(options: options, observing: observing) else { return nil }
            outcome = ibgd.mantel
            report = analysis.report(for: ibgd, options: finished(outcome))
            if let directional {
                let fitOptions = AnalysisOptions(iterations: 0)
                guard let fit = directional.run(options: fitOptions) else { return nil }
                directionalOutcome = fit
                let second = directional.report(for: fit, options: fitOptions)
                report = AnalysisReport(analysisType: second.analysisType, tag: second.tag, options: report.options,
                                        methods: report.methods + " " + second.methods,
                                        results: report.results + " " + second.results,
                                        notes: report.notes + second.notes, date: report.date)
            }
        }
        let x = outcome.points.map(\.x)
        let y = outcome.points.map(\.y)
        let pearson = pearsonCorrelation(x, y)
        var summary = IBDSpec.Summary(r: outcome.r, p: outcome.distribution?.pValue(),
                                      slope: outcome.line?.slope, intercept: outcome.line?.intercept,
                                      r2: pearson.isFinite ? pearson * pearson : nil, pairs: outcome.pairCount)
        if let fit = directionalOutcome?.result {
            summary.deltaR2 = fit.deltaR2
            summary.adjustedR2 = fit.adjustedR2DCGD
            summary.forwardSlope = fit.forwardSlope
            summary.reverseSlope = fit.reverseSlope
            summary.slopeRatio = fit.slopeRatio
            summary.directedIntercept = directionalOutcome?.intercept
            summary.orderedPairs = fit.pairs
        }
        spec.result = summary
        return IBDResult(spec: spec, outcome: outcome, directional: directionalOutcome, report: report,
                         isParentOffspring: isParentOffspring, unlocated: unlocated)
    }
}
