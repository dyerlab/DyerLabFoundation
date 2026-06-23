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
//  DataTable+PlotRows.swift
//
//  Resolution of the role mapping into render-ready `[PlotRow]`.
//

import Foundation

public extension DataTable {

    /// The value kind of the column bound to the ``DataColumnRole/x`` role.
    var xKind: ColumnKind? {
        guard let name = roles[.x] else { return nil }
        return kind(of: name)
    }

    /// The distinct, sorted series values, for legends and color domains.
    ///
    /// Empty when no ``DataColumnRole/series`` role is bound.
    var seriesValues: [String] {
        guard let name = roles[.series] else { return [] }
        return Set(stringColumn(name).compactMap { $0 }).sorted()
    }

    /// The table resolved into chart-ready rows.
    ///
    /// Requires both an `x` and a `y` role. Rows whose `x` is missing, or
    /// whose `y` is missing or non-finite, are skipped.
    var plotRows: [PlotRow] {
        guard let xName = roles[.x], let yName = roles[.y] else { return [] }

        let xs = plotValues(xName)
        let ys = numericColumn(yName)
        let seriesVals = roles[.series].map { stringColumn($0) }
        let labelVals  = roles[.label].map  { stringColumn($0) }

        var rows: [PlotRow] = []
        let count = Swift.min(xs.count, ys.count)
        rows.reserveCapacity(count)
        for i in 0 ..< count {
            guard let x = xs[i], let y = ys[i], y.isFinite else { continue }
            rows.append(PlotRow(id: i,
                                x: x,
                                y: y,
                                series: seriesVals.flatMap { i < $0.count ? $0[i] : nil },
                                label:  labelVals.flatMap  { i < $0.count ? $0[i] : nil }))
        }
        return rows
    }
}
