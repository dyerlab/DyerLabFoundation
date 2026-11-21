//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IBDSpec.swift
//  PopulationGenetics
//
//  An isolation-by-distance analysis, gstudio's `genetic_isolation()`: a genetic
//  distance matrix tested against separation among the same units with a Mantel
//  test. Separation is great-circle distance, another matrix, or the difference
//  along an `Axis`. With dcGD as the genetic distance it is directional isolation
//  by graph distance: the Mantel test of cGD (isolation by graph distance), then
//  dcGD regressed on separation with forward and reverse slopes, whose ΔR² says
//  whether direction improves the fit (gstudio's `ibgd(mode = "cGD")` and
//  `ibgd(mode = "dcGD")`).
//  A saved analysis is one scatter figure (generator `ibd_analysis`) whose
//  spec is this JSON, results included, so R reads the inputs and the
//  numbers from one row; the matrices themselves are named by their
//  `DistanceSpec`s and recomputed rather than stored. The raw values and the
//  keys are part of the file format; don't change them.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix

/// The parameters, and once run the results, of an isolation-by-distance analysis.
public struct IBDSpec: Codable, Hashable, Sendable {

    /// How genetic distance is transformed before the test.
    public enum Transform: String, Codable, CaseIterable, Identifiable, Sendable {
        /// The distances as they are.
        case none
        /// Rousset's (1997) linearization of a differentiation statistic, `F / (1 − F)`; only for pairwise Φ_ST.
        case rousset

        /// The transform itself.
        public var id: Self { self }
    }

    /// What the test found, kept with the spec so a saved analysis carries its numbers.
    public struct Summary: Codable, Hashable, Sendable {
        /// The Mantel correlation.
        public var r: Double
        /// The permutation P, or `nil` when untested.
        public var p: Double?
        /// The least-squares slope of genetic distance on separation, if there is one.
        public var slope: Double?
        /// The least-squares intercept, if there is one.
        public var intercept: Double?
        /// The share of variance in genetic distance the regression explains (the squared Pearson correlation).
        public var r2: Double?
        /// The number of pairs tested.
        public var pairs: Int
        /// For dcGD, `ΔR² = adjusted R²_dcGD − R²_cGD`, where ``r2`` is R²_cGD; positive favours the directional
        /// description.
        public var deltaR2: Double?
        /// For dcGD, the adjusted R² of `dcGD ~ d + d:reverse`.
        public var adjustedR2: Double?
        /// For dcGD, the slope for pairs running forward.
        public var forwardSlope: Double?
        /// For dcGD, the slope for pairs running in reverse.
        public var reverseSlope: Double?
        /// For dcGD, `forwardSlope / reverseSlope`; below one, genetic distance accumulates more slowly forward.
        public var slopeRatio: Double?
        /// For dcGD, the fit's intercept, which both directions share.
        public var directedIntercept: Double?
        /// For dcGD, the ordered pairs in the fit.
        public var orderedPairs: Int?

        /// Creates a summary.
        ///
        /// - Parameters:
        ///   - r: The Mantel correlation.
        ///   - p: The permutation P, or `nil`.
        ///   - slope: The regression slope.
        ///   - intercept: The regression intercept.
        ///   - r2: The regression's R².
        ///   - pairs: The pairs tested.
        public init(r: Double, p: Double?, slope: Double?, intercept: Double?, r2: Double?, pairs: Int) {
            self.r = r
            self.p = p
            self.slope = slope
            self.intercept = intercept
            self.r2 = r2
            self.pairs = pairs
        }

        /// Whether the summary includes a directional fit.
        public var isDirectional: Bool {
            deltaR2 != nil
        }
    }

    /// The default number of permutations.
    public static let defaultPermutations = 999

    /// The genetic distances; dcGD makes the analysis directional.
    public var genetic: DistanceSpec
    /// What the genetic distances are tested against, at the same level: great-circle distance by default, or
    /// another genetic distance for a Mantel test between two genetic matrices. Not used when ``alongAxis``.
    public var against: DistanceSpec.Measure
    /// A position for each unit along a hypothesized axis, or `nil`. dcGD needs one for its direction.
    public var axis: Axis?
    /// Whether separation is the difference along ``axis`` rather than ``against``; with `false`, the axis only
    /// gives dcGD its direction.
    public var alongAxis: Bool
    /// The bandwidth multiplier γ for dcGD (default 0.5).
    public var gamma: Double
    /// How the genetic distances are transformed.
    public var transform: Transform
    /// Whether separation is log-transformed, as Rousset expects for a two-dimensional habitat.
    public var logSeparation: Bool
    /// The Mantel correlation.
    public var method: CorrelationMethod
    /// The number of permutations, or 0 for no test.
    public var permutations: Int
    /// The permutations' seed, or `nil` when untested.
    public var seed: UInt64?
    /// What the test found, or `nil` before it has run.
    public var result: Summary?

    private enum CodingKeys: String, CodingKey {
        case genetic, separation, transform, logSeparation, method, permutations, seed, result, axis, alongAxis, gamma
    }

    // MARK: - Initialization

    /// Creates a spec.
    ///
    /// - Parameters:
    ///   - genetic: The genetic distances (default pairwise Φ_ST among `Population`).
    ///   - against: What they are tested against (default great-circle distance).
    ///   - transform: Their transform (default Rousset's for Φ_ST, otherwise none).
    ///   - logSeparation: Whether separation is log-transformed (default `false`).
    ///   - method: The correlation (default Pearson).
    ///   - axis: A hypothesized axis (default none).
    ///   - alongAxis: Whether separation is along `axis` (default `true` when there is one).
    ///   - gamma: The bandwidth multiplier for dcGD (default 0.5).
    ///   - permutations: The number of permutations (default 0, untested).
    ///   - seed: The permutations' seed.
    ///   - result: What the test found.
    public init(genetic: DistanceSpec = DistanceSpec(measure: .phiST, level: "Population"),
                against: DistanceSpec.Measure = .greatCircle,
                transform: Transform? = nil,
                logSeparation: Bool = false,
                method: CorrelationMethod = .pearson,
                axis: Axis? = nil,
                alongAxis: Bool? = nil,
                gamma: Double = DistanceAnalysis.defaultGamma,
                permutations: Int = 0,
                seed: UInt64? = nil,
                result: Summary? = nil) {
        self.genetic = genetic
        self.against = against
        self.transform = transform ?? (genetic.measure == .phiST ? .rousset : .none)
        self.logSeparation = logSeparation
        self.method = method
        self.axis = axis
        self.alongAxis = axis != nil && (alongAxis ?? true)
        self.gamma = gamma
        self.permutations = permutations
        self.seed = seed
        self.result = result
    }

    /// Decodes a spec; `separation` names what the genetic distances were tested against, great-circle distance
    /// when absent (specs written before other matrices could be, or separated along their axis). `axis`,
    /// `alongAxis` and `gamma` are absent from specs written before axes and dcGD.
    ///
    /// - Parameter decoder: The decoder to read from.
    /// - Throws: A `DecodingError` when a field is missing or unknown.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        genetic = try container.decode(DistanceSpec.self, forKey: .genetic)
        against = try container.decodeIfPresent(DistanceSpec.self, forKey: .separation)?.measure ?? .greatCircle
        transform = try container.decode(Transform.self, forKey: .transform)
        logSeparation = try container.decode(Bool.self, forKey: .logSeparation)
        method = try container.decode(CorrelationMethod.self, forKey: .method)
        permutations = try container.decodeIfPresent(Int.self, forKey: .permutations) ?? 0
        seed = try container.decodeIfPresent(UInt64.self, forKey: .seed)
        result = try container.decodeIfPresent(Summary.self, forKey: .result)
        axis = try container.decodeIfPresent(Axis.self, forKey: .axis)
        let alongAxis = try container.decodeIfPresent(Bool.self, forKey: .alongAxis)
        self.alongAxis = axis != nil && (alongAxis ?? true)
        gamma = try container.decodeIfPresent(Double.self, forKey: .gamma) ?? DistanceAnalysis.defaultGamma
    }

    /// Encodes the spec, with the separation matrix it is tested against unless it is separated along its axis, and
    /// γ only for dcGD.
    ///
    /// - Parameter encoder: The encoder to write to.
    /// - Throws: Whatever the encoder throws.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(genetic, forKey: .genetic)
        if !alongAxis { try container.encode(separation, forKey: .separation) }
        if let axis {
            try container.encode(axis, forKey: .axis)
            try container.encode(alongAxis, forKey: .alongAxis)
        }
        if isDirectional { try container.encode(gamma, forKey: .gamma) }
        try container.encode(transform, forKey: .transform)
        try container.encode(logSeparation, forKey: .logSeparation)
        try container.encode(method, forKey: .method)
        try container.encode(permutations, forKey: .permutations)
        try container.encodeIfPresent(seed, forKey: .seed)
        try container.encodeIfPresent(result, forKey: .result)
    }

    // MARK: - Contents

    /// The matrix the genetic distances are tested against, among the same units.
    public var separation: DistanceSpec {
        DistanceSpec(measure: against, level: genetic.level)
    }

    /// Whether the genetic distances are tested against geographic distance, which is isolation by distance:
    /// great-circle distance or the difference along an axis.
    public var isGeographic: Bool { alongAxis || against == .greatCircle }

    /// Whether the analysis is directional isolation by graph distance, with dcGD as the genetic distance.
    public var isDirectional: Bool { genetic.measure == .dcgd }

    /// The spec's JSON, with sorted keys, as a figure's `spec` stores it.
    public var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    /// Whether a permutation test has been run.
    public var isTested: Bool {
        permutations > 0 && seed != nil
    }

    /// The spec without its test or results, for comparing what is on the page with what was saved.
    public var untested: IBDSpec {
        var spec = self
        spec.permutations = 0
        spec.seed = nil
        spec.result = nil
        return spec
    }

    /// The transform the genetic measure allows: Rousset's only for pairwise Φ_ST.
    public var validTransform: Transform {
        genetic.measure == .phiST ? transform : .none
    }

    /// The genetic axis's title, such as "Φ_ST / (1 − Φ_ST)" or, for a directional analysis, "dcGD".
    public var geneticLabel: String {
        if isDirectional { return "dcGD" }
        return switch validTransform {
        case .rousset: "Φ_ST / (1 − Φ_ST)"
        case .none: genetic.measure.title
        }
    }

    /// The separation axis's title, such as "ln great-circle distance (km)" or "Nei's distance".
    public var separationLabel: String {
        if alongAxis, let axis { return (logSeparation ? "ln " : "") + axis.separationLabel }
        guard isGeographic else { return (logSeparation ? "ln " : "") + against.title }
        return (logSeparation ? "ln great-circle distance" : "Great-circle distance") + " (km)"
    }

    /// The separation as prose, such as "great-circle distance (km)", for Methods text.
    public var separationPhrase: String {
        if alongAxis, let axis { return axis.separationPhrase }
        return isGeographic ? "great-circle distance (km)" : against.title
    }

    /// The analysis as a formula, such as `Φ_ST/(1−Φ_ST) ~ ln km | Population` or `Nei ~ cGD | Population`.
    public var formula: String {
        let response = validTransform == .rousset ? "Φ_ST/(1−Φ_ST)" : genetic.measure.symbol
        let separation = alongAxis ? axis?.symbol ?? "Δaxis" : (isGeographic ? "km" : against.symbol)
        let predictor = (logSeparation ? "ln " : "") + separation
        return "\(response) ~ \(predictor) | \(genetic.level)"
    }

    /// The analysis's title, such as "Isolation by distance among Population".
    ///
    /// - Parameter isParentOffspring: Whether the adults are the mothers of parent/offspring data.
    /// - Returns: The title.
    public func title(isParentOffspring: Bool) -> String {
        let units = genetic.unitName(isParentOffspring: isParentOffspring)
        if isDirectional { return "Directional isolation by graph distance among \(units)" }
        if genetic.measure == .cgd, isGeographic { return "Isolation by graph distance among \(units)" }
        return isGeographic ? "Isolation by distance among \(units)"
                            : "\(genetic.measure.title) against \(against.title) among \(units)"
    }
}
