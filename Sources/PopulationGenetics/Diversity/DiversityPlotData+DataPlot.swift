//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DiversityPlotData+DataPlot.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import PresentationZen
import TabularData

public extension DiversityPlotData {

    /// The plot's values as a table with its roles bound, in the columns an export shows.
    ///
    /// Columns are named so they read in both R and a spreadsheet: the statistic's symbol, and the predictor's
    /// column name.
    ///
    /// - Parameter spec: The plot's parameters, which name the columns.
    /// - Returns: The table, or `nil` if the plot has no values.
    func dataTable(spec: DiversityPlotSpec) -> DataTable? {
        let statistic = spec.response.rawValue
        let predictor = spec.predictor.columnName
        var frame = DataFrame()
        switch content {
        case .distribution(let values):
            frame.append(column: Column(name: statistic, contents: values))
            return DataTable(frame: frame, roles: [.y: statistic])
        case .categories(let categories):
            frame.append(column: Column(name: predictor, contents: categories.map(\.name)))
            frame.append(column: Column(name: statistic, contents: categories.map(\.value)))
            return DataTable(frame: frame, roles: [.x: predictor, .y: statistic])
        case .points(let points):
            frame.append(column: Column(name: "group", contents: points.map(\.name)))
            frame.append(column: Column(name: predictor, contents: points.map(\.x)))
            frame.append(column: Column(name: statistic, contents: points.map(\.y)))
            return DataTable(frame: frame, roles: [.x: predictor, .y: statistic])
        case .unavailable:
            return nil
        }
    }

    /// The plot in PresentationZen's standard form, which draws and exports it.
    ///
    /// - Parameter spec: The plot's parameters.
    /// - Returns: The plot, or `nil` if it has no values.
    @MainActor
    func plot(spec: DiversityPlotSpec) -> DataPlot? {
        guard let table = dataTable(spec: spec), let form = plotForm(spec: spec) else { return nil }
        return DataPlot(table, form: form, xLabel: xLabel, yLabel: yLabel)
    }

    /// The standard form this plot takes.
    ///
    /// - Parameter spec: The plot's parameters.
    /// - Returns: The form, or `nil` if the plot has no values.
    func plotForm(spec: DiversityPlotSpec) -> PlotForm? {
        switch content {
        case .distribution: spec.style == .density ? .density : .histogram(bins: spec.bins)
        case .categories: .bars
        case .points: .scatter
        case .unavailable: nil
        }
    }

    /// Remarks to keep with exported code: which items the plot leaves out for having no data.
    var exportNotes: [String] {
        omitted.isEmpty ? [] : ["Not shown (no data): " + omitted.joined(separator: ", ")]
    }
}
