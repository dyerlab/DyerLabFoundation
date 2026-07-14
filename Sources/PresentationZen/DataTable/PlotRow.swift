//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  PlotRow.swift
//
//  The resolved, render-ready row a chart iterates. A `DataTable` projects
//  its role mapping into `[PlotRow]`; the chart never touches the underlying
//  data frame.
//

import Foundation

/// A single resolved row ready for a chart mark.
///
/// `PlotRow` is the render currency of the charting layer. It is fully
/// `Sendable`, so a resolved `[PlotRow]` can cross actor boundaries even
/// though the originating ``DataTable`` cannot.
public struct PlotRow: Identifiable, Hashable, Sendable {

    /// The originating row index in the data frame (stable across renders).
    public let id: Int

    /// The positional x value, carrying its own kind.
    public let x: PlotValue

    /// The positional y value (always quantitative).
    public let y: Double

    /// The series/color group, when a ``DataColumnRole/series`` role is bound.
    public let series: String?

    /// The per-point annotation, when a ``DataColumnRole/label`` role is bound.
    public let label: String?

    /// Creates a resolved plot row.
    ///
    /// - Parameters:
    ///   - id: The originating row index in the data frame.
    ///   - x: The positional x value.
    ///   - y: The positional y value.
    ///   - series: The series/color group, if bound (defaults to `nil`).
    ///   - label: The per-point annotation, if bound (defaults to `nil`).
    public init(id: Int, x: PlotValue, y: Double, series: String? = nil, label: String? = nil) {
        self.id = id
        self.x = x
        self.y = y
        self.series = series
        self.label = label
    }
}
