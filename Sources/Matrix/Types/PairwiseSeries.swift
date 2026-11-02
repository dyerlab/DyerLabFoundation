//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PairwiseSeries.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// A named set of pairwise points with an optional fitted line — e.g. all
/// population pairs, or just the forward (downstream) ones.
public struct PairwiseSeries: Sendable, Equatable, Hashable {

    /// The series' name, shown in a legend.
    public let name: String

    /// The points.
    public let points: [PairwisePoint]

    /// The fitted line, or `nil` to draw points only.
    public let line: RegressionLine?

    /// Creates a series.
    ///
    /// - Parameters:
    ///   - name: The series' name.
    ///   - points: The points.
    ///   - line: The fitted line, or `nil` (default).
    public init(name: String, points: [PairwisePoint], line: RegressionLine? = nil) {
        self.name = name
        self.points = points
        self.line = line
    }
}
