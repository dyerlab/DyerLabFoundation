//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PlotForm.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// A standard way to draw a ``DataTable``, which says which roles the table must bind.
public enum PlotForm: Hashable, Sendable {
    /// Counts in equal-width bins of the `y` column, drawn at their true edges.
    case histogram(bins: Int)
    /// A Gaussian kernel density curve of the `y` column.
    case density
    /// A bar for each row: categorical `x`, quantitative `y`.
    case bars
    /// A point for each row: quantitative `x` and `y`.
    case scatter

    /// Beyond this many bars, category labels are rotated so they don't collide.
    public static let horizontalLabelLimit = 8
}
