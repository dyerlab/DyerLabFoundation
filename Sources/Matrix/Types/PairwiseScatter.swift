//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PairwiseScatter.swift
//  Matrix
//
//  The plot-ready form shared by every pairwise analysis (isolation by
//  distance, by graph distance, directional graph distance), so one view can
//  draw them all. It is data only; PresentationZen draws it.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// Pairwise points in one or more series, with axis labels.
public struct PairwiseScatter: Sendable, Equatable, Hashable {

    /// The horizontal (predictor) axis label.
    public let xLabel: String

    /// The vertical (response) axis label.
    public let yLabel: String

    /// The series, in legend order.
    public let series: [PairwiseSeries]

    /// Creates a scatter.
    ///
    /// - Parameters:
    ///   - xLabel: The predictor axis label.
    ///   - yLabel: The response axis label.
    ///   - series: The series, in legend order.
    public init(xLabel: String, yLabel: String, series: [PairwiseSeries]) {
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.series = series
    }

    /// Every point across all series.
    public var points: [PairwisePoint] { series.flatMap(\.points) }
}
