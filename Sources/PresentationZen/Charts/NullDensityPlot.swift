//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  NullDensityPlot.swift
//  PresentationZen
//
//  The finished form of a permutation test, for a frozen result: the density of the permuted values with the
//  observed value marked. The running-P trace of `NullDistributionView` shows how a live test settles and has
//  nothing to say once it has, so it is left out. Permuted values that are all equal have no density, so they are
//  drawn as a single rule.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Charts
import Matrix
import SwiftUI

/// A permutation test's null distribution as a density, with the observed statistic and P.
public struct NullDensityPlot: View {
    /// The observed statistic.
    public let observed: Double
    /// The permuted statistics.
    public let values: [Double]
    /// The statistic's symbol, such as `Φ_ST`.
    public let statisticLabel: String
    /// Which permuted values count as at least as extreme as the observed one.
    public let direction: NullDistributionResult.ComparisonDirection
    /// The test, for its P.
    private let result: NullDistributionResult

    // MARK: - Initialization

    /// Creates the plot from a finished test.
    ///
    /// - Parameters:
    ///   - result: The test's observed value and permuted values.
    ///   - statisticLabel: The statistic's symbol, such as `Φ_ST`.
    ///   - direction: Which permuted values count as extreme (default: at least as large).
    public init(_ result: NullDistributionResult, statisticLabel: String,
                direction: NullDistributionResult.ComparisonDirection = .greaterOrEqual) {
        self.observed = result.observed
        self.values = result.values.filter(\.isFinite)
        self.statisticLabel = statisticLabel
        self.direction = direction
        self.result = result
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(caption)
                .font(.headline)
                .monospacedDigit()
            Chart {
                ForEach(curve) { point in
                    AreaMark(x: .value(statisticLabel, point.x), y: .value("Density", point.density))
                        .foregroundStyle(.tint.opacity(0.35))
                    LineMark(x: .value(statisticLabel, point.x), y: .value("Density", point.density))
                        .foregroundStyle(.tint)
                }
                if curve.isEmpty, let value = values.first {
                    RuleMark(x: .value(statisticLabel, value))
                        .foregroundStyle(.tint)
                }
                RuleMark(x: .value("Observed", observed))
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .annotation(position: .top, alignment: .center) {
                        Text("observed").font(.caption2).foregroundStyle(.red)
                    }
            }
            .chartXScale(domain: xDomain)
            .chartXAxisLabel("Permuted \(statisticLabel)")
            .chartYAxisLabel("Density")
        }
    }

    // MARK: - Numbers

    /// The density curve, or `[]` if the permuted values are all equal.
    private var curve: [DensityPoint] {
        guard let low = values.min(), let high = values.max(), high > low else { return [] }
        return KernelDensity(values)
    }

    /// The axis range, wide enough for the curve and the observed value.
    private var xDomain: ClosedRange<Double> {
        let xs = curve.map(\.x) + values + [observed]
        guard let low = xs.min(), let high = xs.max() else { return 0...1 }
        let pad = high > low ? (high - low) * 0.05 : max(abs(high) * 0.05, 0.01)
        return (low - pad)...(high + pad)
    }

    /// P and how many permutations it rests on.
    private var caption: String {
        let p = result.pValue(direction: direction)
        return "P = \(p.formatted(.number.precision(.significantDigits(3)))) from "
            + "\(result.values.count.formatted()) permutations; observed \(statisticLabel) = "
            + "\(observed.formatted(.number.precision(.significantDigits(4))))"
    }
}

// MARK: - Previews

#Preview("Strong structure") {
    let values = (0..<999).map { Double($0 % 37) / 2000 + Double($0 % 11) / 4000 }
    NullDensityPlot(NullDistributionResult(analysisType: AnalysisTag("preview"), observed: 0.08, values: values),
                    statisticLabel: "Φ_ST")
        .frame(width: 520, height: 300)
        .padding()
}
