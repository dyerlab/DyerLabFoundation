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

public struct RegressionResult {
    public let slope: Double
    public let intercept: Double
    public let r2: Double
    public let fitted: [DataPoint]
    public var isEmpty: Bool { fitted.isEmpty }

    public init(slope: Double = Double.nan, intercept: Double = Double.nan, r2: Double = Double.nan, fitted: [DataPoint] = []) {
        self.slope = slope
        self.intercept = intercept
        self.r2 = r2
        self.fitted = fitted
    }
}
