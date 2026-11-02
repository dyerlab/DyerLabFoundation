//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AnalysisType.swift
//  Matrix
//
//  The catalogue of analysis techniques. It is an open, string-backed struct
//  rather than an enum (the Swift Coding Protocol's rule for extensible
//  categories): Mantel, AMOVA and rarefaction are defined here, and
//  PopulationGenetics adds outcrossing and correlated paternity with `static let`
//  extensions, which a closed enum in Matrix could not allow without Matrix
//  naming every genetics technique.
//
//  `AnalysisType` names the technique; `AnalysisTag` labels a particular use
//  of it (AMOVA's Φ_ST vs. a single-locus θ). Every type has a default tag.
//  Identity is the `rawValue` alone: two values with the same label are equal
//  whatever their descriptive fields say.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// An analysis technique, with the inputs it takes.
///
/// Any module can define its own techniques with a `static let` extension.
public struct AnalysisType: Sendable, Hashable, CustomStringConvertible {

    /// The technique's unique label.
    public let rawValue: String

    /// A human-readable name.
    public let displayName: String

    /// The inputs the technique takes, in order.
    public let operands: [AnalysisOperand]

    /// Whether the technique is driven by a number of resampling iterations
    /// (permutations or subsamples), read from `AnalysisOptions.iterations`.
    public let usesIterations: Bool

    /// Creates a technique.
    ///
    /// - Parameters:
    ///   - rawValue: The technique's unique label.
    ///   - displayName: A human-readable name.
    ///   - operands: The inputs it takes, in order.
    ///   - usesIterations: Whether `AnalysisOptions.iterations` applies.
    public init(_ rawValue: String, displayName: String, operands: [AnalysisOperand], usesIterations: Bool) {
        self.rawValue = rawValue
        self.displayName = displayName
        self.operands = operands
        self.usesIterations = usesIterations
    }

    /// The technique's label.
    public var description: String { rawValue }

    /// The default label for results of this technique.
    public var tag: AnalysisTag { AnalysisTag(rawValue) }

    // MARK: - Identity

    /// Two techniques are equal when their labels are.
    ///
    /// - Parameters:
    ///   - lhs: A technique.
    ///   - rhs: Another technique.
    /// - Returns: Whether the labels match.
    public static func == (lhs: AnalysisType, rhs: AnalysisType) -> Bool {
        lhs.rawValue == rhs.rawValue
    }

    /// Hashes the label.
    ///
    /// - Parameter hasher: The hasher to feed.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }

    // MARK: - Built-in techniques

    /// Mantel test: the correlation between two pairwise matrices over the
    /// same units, tested by permuting one matrix's rows and columns together.
    public static let mantel = AnalysisType("mantel",
                                            displayName: "Mantel Test",
                                            operands: [AnalysisOperand(role: "response", kind: .pairwise),
                                                       AnalysisOperand(role: "predictor", kind: .pairwise)],
                                            usesIterations: true)

    /// Analysis of molecular variance: partitions a squared-distance matrix
    /// among and within groups, tested by permuting group membership. With
    /// genetic distances this is AMOVA's Φ_ST (θ for a single locus); with
    /// pollen-pool distances it is 2Gener's Φ_FT.
    public static let amova = AnalysisType("amova",
                                           displayName: "AMOVA",
                                           operands: [AnalysisOperand(role: "distances", kind: .pairwise),
                                                      AnalysisOperand(role: "groups", kind: .partition)],
                                           usesIterations: true)

    /// Rarefaction: a statistic re-estimated over repeated subsamples of a
    /// smaller size, so samples of different sizes can be compared.
    public static let rarefaction = AnalysisType("rarefaction",
                                                 displayName: "Rarefaction",
                                                 operands: [AnalysisOperand(role: "sample", kind: .sample)],
                                                 usesIterations: true)
}
