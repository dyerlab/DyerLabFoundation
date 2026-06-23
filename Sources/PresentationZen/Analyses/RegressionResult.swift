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

/// The result of a linear regression: coefficients plus the fitted line.
///
/// `fitted` carries ``PlotRow`` values so the result is fully `Sendable` and
/// can be computed off the main actor and handed straight to a chart.
public struct RegressionResult: Sendable {
    public let slope: Double
    public let intercept: Double
    public let r2: Double
    public let fitted: [PlotRow]
    public var isEmpty: Bool { fitted.isEmpty }

    public init(slope: Double = Double.nan,
                intercept: Double = Double.nan,
                r2: Double = Double.nan,
                fitted: [PlotRow] = []) {
        self.slope = slope
        self.intercept = intercept
        self.r2 = r2
        self.fitted = fitted
    }
}
