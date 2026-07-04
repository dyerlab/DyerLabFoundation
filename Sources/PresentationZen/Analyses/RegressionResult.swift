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
//  RegressionResult.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026-02-16.
//

import Foundation
import Matrix

/// The result of a linear regression: coefficients plus the fitted line.
///
/// `fitted` carries ``PlotRow`` values so the result is fully `Sendable` and
/// can be computed off the main actor and handed straight to a chart.
///
/// The coefficients themselves stay plain `Double` properties for the same
/// reason: `DataTable` wraps a `TabularData.DataFrame` and isn't `Sendable`,
/// so it can't be stored on a cross-actor result type. ``summary`` builds one
/// on demand for callers that want the standardized tabular form (e.g. to
/// hand to `DataTableView` or a chart) instead of the raw scalars.
///
/// `fit` carries the full ``LinearModelFit`` (df/SS/MS/F breakdown) computed
/// by `dateRegression(_:)`; it's `nil` when a `RegressionResult` is built
/// directly rather than fit from data. Pass it to `anovaTable(_:)` — or just
/// pass this whole result to the `anovaTable(_:)` overload that accepts one.
public struct RegressionResult: Sendable {
    public let slope: Double
    public let intercept: Double
    public let r2: Double
    public let fitted: [PlotRow]
    public let fit: LinearModelFit?
    public var isEmpty: Bool { fitted.isEmpty }

    public init(slope: Double = Double.nan,
                intercept: Double = Double.nan,
                r2: Double = Double.nan,
                fitted: [PlotRow] = [],
                fit: LinearModelFit? = nil) {
        self.slope = slope
        self.intercept = intercept
        self.r2 = r2
        self.fitted = fitted
        self.fit = fit
    }

    /// The coefficients as a `coefficient`/`value` ``DataTable``, with `x`/`y`
    /// roles already bound for plotting.
    public var summary: DataTable {
        DataTable(
            numbers: ["value": [slope, intercept, r2]],
            strings: ["coefficient": ["slope", "intercept", "rSquared"]],
            roles: [.x: "coefficient", .y: "value"]
        )
    }
}
