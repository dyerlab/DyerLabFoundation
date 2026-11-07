//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  KernelDensity.swift
//  Matrix
//
//  Follows R's `density()` defaults (Gaussian kernel, `bw.nrd0` bandwidth, curve
//  running three bandwidths past the data) so a density plot here matches one
//  made from the same values in R. As in R, the tails can run past a statistic's
//  natural bounds (He below 0).
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Estimates a density curve with a Gaussian kernel, a port of R's `density()` with its default arguments.
///
/// Each point is evaluated directly rather than by R's binned FFT, so densities agree with R's to about 0.001
/// while the grid and bandwidth match exactly.
///
/// - Parameters:
///   - values: The observations.
///   - points: The number of points along the curve.
/// - Returns: The curve, or `[]` if there are no observations.
public func KernelDensity(_ values: [Double], points: Int = 128) -> [DensityPoint] {
    guard let low = values.min(), let high = values.max(), points > 1 else { return [] }
    let bandwidth = SilvermanBandwidth(values)
    let start = low - 3 * bandwidth
    let step = (high + 3 * bandwidth - start) / Double(points - 1)
    let scale = 1 / (Double(values.count) * bandwidth * (2 * Double.pi).squareRoot())
    return (0..<points).map { index in
        let x = start + Double(index) * step
        let sum = values.reduce(0) { total, value in
            let z = (x - value) / bandwidth
            return total + exp(-0.5 * z * z)
        }
        return DensityPoint(x: x, density: scale * sum)
    }
}
