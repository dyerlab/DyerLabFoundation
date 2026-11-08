//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DistanceResult.swift
//  PopulationGenetics
//
//  A pairwise distance matrix and what goes with it on the page: the group
//  each row belongs to (for an individual matrix, its innermost stratum, so
//  the heatmap can mark the strata), and the units left out for want of
//  coordinates. It is computed when needed, never stored.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix
import PresentationZen

/// A pairwise distance matrix, ready to show or store.
public struct DistanceResult: Sendable, Equatable {

    /// What the matrix holds.
    public let spec: DistanceSpec
    /// The distances, with one name per unit.
    public let matrix: UnitDistanceMatrix
    /// Each row's group, such as its population, or `nil` when the rows are strata or have no strata.
    public let groups: [String]?
    /// The units left out, for the reason ``omissionReason`` gives.
    public let omitted: [String]
    /// Why ``omitted`` were left out, such as "no coordinates".
    public let omissionReason: String
    /// The matrix's name, such as "Great-circle distance among Population".
    public let name: String
    /// What the matrix is among, as the legend and log say it: "individuals", "mothers" or a level.
    public let unitName: String

    /// Creates a result.
    ///
    /// - Parameters:
    ///   - spec: What the matrix holds.
    ///   - matrix: The distances.
    ///   - groups: Each row's group, or `nil`.
    ///   - omitted: The units left out.
    ///   - omissionReason: Why they were left out (default "no coordinates").
    ///   - isParentOffspring: Whether the adults are the mothers of parent/offspring data.
    public init(spec: DistanceSpec, matrix: UnitDistanceMatrix, groups: [String]? = nil, omitted: [String] = [],
                omissionReason: String = "no coordinates", isParentOffspring: Bool = false) {
        self.spec = spec
        self.matrix = matrix
        self.groups = groups
        self.omitted = omitted
        self.omissionReason = omissionReason
        self.name = spec.name(isParentOffspring: isParentOffspring)
        self.unitName = spec.unitName(isParentOffspring: isParentOffspring)
    }

    // MARK: - Contents

    /// The number of units.
    public var count: Int {
        matrix.groupNames.count
    }

    /// Each distance once: the upper triangle, row by row.
    public var pairwiseValues: [Double] {
        var values: [Double] = []
        values.reserveCapacity(count * (count - 1) / 2)
        for i in 0..<count {
            for j in (i + 1)..<count { values.append(matrix[i, j]) }
        }
        return values
    }

    /// What was computed, for the legend and the log's Methods.
    public var methods: String {
        let units: String
        if spec.isAmongIndividuals {
            units = "\(count) \(unitName)"
        } else if spec.measure == .greatCircle {
            units = "the centroids of \(count) \(spec.level) strata (the mean of each stratum's distinct coordinates)"
        } else {
            units = "\(count) \(spec.level) strata"
        }
        return "\(spec.measure.methods), among \(units)."
    }
}
