//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  DataTable+NullDistribution.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 7/14/26.
//

import Matrix

public extension DataTable {

    /// Bins a `NullDistributionResult`'s comparison distribution (permuted
    /// nulls, or resampled estimates) into a histogram table ready for
    /// `DistributionPlot` — pass `result.observed` separately as that view's
    /// `referenceLine` to mark where the observed value falls.
    ///
    /// - Parameters:
    ///   - result: The null/comparison distribution to bin.
    ///   - bins: The number of equal-width bins.
    init(nullDistribution result: NullDistributionResult, bins: Int = 20) {
        let histogram = Vector(result.values).histogram(bins: bins)
        self.init(numbers: ["value": histogram.map(\.center),
                             "count": histogram.map { Double($0.count) }],
                  roles: [.x: "value", .y: "count"])
    }
}
