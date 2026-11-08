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
//  An isolation-by-distance analysis: a genetic distance matrix tested
//  against great-circle distance among the same units with a Mantel test.
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
    }

    /// The default number of permutations.
    public static let defaultPermutations = 999

    /// The genetic distances.
    public var genetic: DistanceSpec
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
        case genetic, separation, transform, logSeparation, method, permutations, seed, result
    }

    // MARK: - Initialization

    /// Creates a spec.
    ///
    /// - Parameters:
    ///   - genetic: The genetic distances (default pairwise Φ_ST among `Population`).
    ///   - transform: Their transform (default Rousset's for Φ_ST, otherwise none).
    ///   - logSeparation: Whether separation is log-transformed (default `false`).
    ///   - method: The correlation (default Pearson).
    ///   - permutations: The number of permutations (default 0, untested).
    ///   - seed: The permutations' seed.
    ///   - result: What the test found.
    public init(genetic: DistanceSpec = DistanceSpec(measure: .phiST, level: "Population"),
                transform: Transform? = nil,
                logSeparation: Bool = false,
                method: CorrelationMethod = .pearson,
                permutations: Int = 0,
                seed: UInt64? = nil,
                result: Summary? = nil) {
        self.genetic = genetic
        self.transform = transform ?? (genetic.measure == .phiST ? .rousset : .none)
        self.logSeparation = logSeparation
        self.method = method
        self.permutations = permutations
        self.seed = seed
        self.result = result
    }

    /// Decodes a spec; `separation` is written for readers such as R and follows from `genetic`.
    ///
    /// - Parameter decoder: The decoder to read from.
    /// - Throws: A `DecodingError` when a field is missing or unknown.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        genetic = try container.decode(DistanceSpec.self, forKey: .genetic)
        transform = try container.decode(Transform.self, forKey: .transform)
        logSeparation = try container.decode(Bool.self, forKey: .logSeparation)
        method = try container.decode(CorrelationMethod.self, forKey: .method)
        permutations = try container.decodeIfPresent(Int.self, forKey: .permutations) ?? 0
        seed = try container.decodeIfPresent(UInt64.self, forKey: .seed)
        result = try container.decodeIfPresent(Summary.self, forKey: .result)
    }

    /// Encodes the spec, with the separation matrix it is tested against.
    ///
    /// - Parameter encoder: The encoder to write to.
    /// - Throws: Whatever the encoder throws.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(genetic, forKey: .genetic)
        try container.encode(separation, forKey: .separation)
        try container.encode(transform, forKey: .transform)
        try container.encode(logSeparation, forKey: .logSeparation)
        try container.encode(method, forKey: .method)
        try container.encode(permutations, forKey: .permutations)
        try container.encodeIfPresent(seed, forKey: .seed)
        try container.encodeIfPresent(result, forKey: .result)
    }

    // MARK: - Contents

    /// The separation the genetic distances are tested against: great-circle distance among the same units.
    public var separation: DistanceSpec {
        DistanceSpec(measure: .greatCircle, level: genetic.level)
    }

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

    /// The genetic axis's title, such as "Φ_ST / (1 − Φ_ST)".
    public var geneticLabel: String {
        switch validTransform {
        case .rousset: "Φ_ST / (1 − Φ_ST)"
        case .none: genetic.measure.title
        }
    }

    /// The separation axis's title, such as "ln great-circle distance (km)".
    public var separationLabel: String {
        (logSeparation ? "ln great-circle distance" : "Great-circle distance") + " (km)"
    }

    /// The analysis's title, such as "Isolation by distance among Population".
    ///
    /// - Parameter isParentOffspring: Whether the adults are the mothers of parent/offspring data.
    /// - Returns: The title.
    public func title(isParentOffspring: Bool) -> String {
        "Isolation by distance among \(genetic.unitName(isParentOffspring: isParentOffspring))"
    }
}
