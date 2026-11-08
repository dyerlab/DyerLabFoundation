//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DistanceSpec.swift
//  PopulationGenetics
//
//  What a pairwise distance matrix holds: the measure and what it is measured
//  among (the adults themselves, or the strata of one level). Matrices are
//  computed when needed rather than stored, so a spec is what a saved analysis
//  (a Mantel test, an isolation-by-distance plot, a tree) records to name the
//  matrices it was made from; its JSON is also how a stored matrix's `spec`
//  column would say it is a distance matrix. The raw values of `Measure` and
//  the keys are part of the file format; don't change them.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The measure and units of a pairwise distance matrix, and what it is among.
///
/// The measures are in ``DistanceSpec/Measure`` (`DistanceSpec+Measure.swift`).
public struct DistanceSpec: Codable, Hashable, Sendable {

    /// The `level` of a matrix among the adults themselves rather than among strata:
    /// every individual, or the mothers in parent/offspring data.
    public static let individualsLevel = "Individuals"

    /// How distances are measured.
    public var measure: Measure
    /// ``individualsLevel``, or the stratum level whose strata the matrix is among, such as `Population`.
    public var level: String

    private enum CodingKeys: String, CodingKey {
        case measure, level, units
    }

    // MARK: - Initialization

    /// Creates a spec.
    ///
    /// - Parameters:
    ///   - measure: How distances are measured (default great-circle).
    ///   - level: ``individualsLevel`` (the default) or a stratum level.
    public init(measure: Measure = .greatCircle, level: String = DistanceSpec.individualsLevel) {
        self.measure = measure
        self.level = level
    }

    /// Decodes a spec; `units` is written for readers such as R and ignored here.
    ///
    /// - Parameter decoder: The decoder to read from.
    /// - Throws: A `DecodingError` when the measure or level is missing or unknown.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        measure = try container.decode(Measure.self, forKey: .measure)
        level = try container.decode(String.self, forKey: .level)
    }

    /// Encodes the spec, with the units of its measure.
    ///
    /// - Parameter encoder: The encoder to write to.
    /// - Throws: Whatever the encoder throws.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(measure, forKey: .measure)
        try container.encode(level, forKey: .level)
        try container.encodeIfPresent(measure.units, forKey: .units)
    }

    /// Reads a spec from a matrix's `spec` column.
    ///
    /// - Parameter json: The column's text.
    /// - Returns: The spec, or `nil` when the text is missing or isn't a distance spec.
    public init?(json: String?) {
        guard let data = json?.data(using: .utf8),
              let spec = try? JSONDecoder().decode(DistanceSpec.self, from: data) else { return nil }
        self = spec
    }

    // MARK: - Contents

    /// The spec as the JSON stored in a matrix's `spec` column, with sorted keys.
    public var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    /// Whether the matrix is among the adults themselves rather than among strata.
    public var isAmongIndividuals: Bool {
        level == Self.individualsLevel
    }

    /// Whether the measure can be computed at the spec's level.
    public var isValid: Bool {
        isAmongIndividuals ? measure.isAmongIndividuals : measure.isAmongStrata
    }

    /// The matrix's name, such as "Great-circle distance among Population".
    ///
    /// - Parameter isParentOffspring: Whether the adults are the mothers of parent/offspring data.
    /// - Returns: The name.
    public func name(isParentOffspring: Bool) -> String {
        "\(measure.title) among \(unitName(isParentOffspring: isParentOffspring))"
    }

    /// What the matrix is among: "individuals", "mothers", or the stratum level.
    ///
    /// - Parameter isParentOffspring: Whether the adults are the mothers of parent/offspring data.
    /// - Returns: The units' name.
    public func unitName(isParentOffspring: Bool) -> String {
        guard isAmongIndividuals else { return level }
        return isParentOffspring ? "mothers" : "individuals"
    }
}
