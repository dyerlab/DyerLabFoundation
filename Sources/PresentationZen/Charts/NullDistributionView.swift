//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  NullDistributionView.swift
//  PresentationZen
//
//  A permutation test as it runs: the permuted values accumulating in a
//  histogram against the observed value, and P (add-one, as
//  `NullDistributionResult` computes it) traced against the number of
//  permutations, so the user can see whether it has settled long before the
//  floor of 1/(n + 1) is reached. It is drawn from the values so far, so the
//  same view shows a finished test.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Charts
import Matrix
import SwiftUI

/// A permutation test's null distribution and running P, live or finished.
public struct NullDistributionView: View {

    /// One histogram bar.
    private struct Bin: Identifiable {
        let id: Int
        let lower: Double
        let upper: Double
        let count: Int
    }

    /// One point of the P trace.
    private struct TracePoint: Identifiable {
        var id: Int { done }
        let done: Int
        let p: Double
    }

    /// The number of histogram bins.
    private static let binCount = 30
    /// The most points the P trace draws.
    private static let tracePoints = 200

    /// The observed statistic.
    public let observed: Double
    /// The permuted statistics so far, in the order drawn.
    public let values: [Double]
    /// The number of permutations the test will draw.
    public let total: Int
    /// The statistic's symbol, such as `Φ_ST`.
    public let statisticLabel: String
    /// Which permuted values count as at least as extreme as the observed one.
    public let direction: NullDistributionResult.ComparisonDirection

    /// Creates the view.
    ///
    /// - Parameters:
    ///   - observed: The observed statistic.
    ///   - values: The permuted statistics so far, in the order drawn.
    ///   - total: The number of permutations the test will draw.
    ///   - statisticLabel: The statistic's symbol.
    ///   - direction: Which values count as extreme (default: at least the observed value).
    public init(observed: Double, values: [Double], total: Int, statisticLabel: String,
                direction: NullDistributionResult.ComparisonDirection = .greaterOrEqual) {
        self.observed = observed
        self.values = values
        self.total = max(total, values.count)
        self.statisticLabel = statisticLabel
        self.direction = direction
    }

    /// Creates the view for a finished test.
    ///
    /// - Parameters:
    ///   - result: The null distribution.
    ///   - statisticLabel: The statistic's symbol.
    ///   - direction: Which values count as extreme (default: at least the observed value).
    public init(_ result: NullDistributionResult, statisticLabel: String,
                direction: NullDistributionResult.ComparisonDirection = .greaterOrEqual) {
        self.init(observed: result.observed, values: result.values, total: result.values.count,
                  statisticLabel: statisticLabel, direction: direction)
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            summary
            trace
                .frame(height: 110)
            histogram
                .frame(height: 180)
        }
    }

    private var summary: some View {
        let p = pValue
        let floor = 1 / Double(total + 1)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 16) {
                Text("P = \(values.isEmpty ? "–" : Self.format(p))")
                    .font(.headline)
                    .monospacedDigit()
                Text("\(extremeCount.formatted()) of \(values.count.formatted()) permuted \(statisticLabel) "
                     + "\(comparison) observed \(Self.format(observed))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if values.count < total {
                Text("\(values.count.formatted()) of \(total.formatted()) permutations; "
                     + "the smallest P this test can give is \(Self.format(floor)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if extremeCount == 0 {
                Text("No permutation reached the observed value: P is at its floor, 1/(\(total.formatted()) + 1).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Charts

    private var histogram: some View {
        Chart {
            ForEach(bins) { bin in
                RectangleMark(xStart: .value(statisticLabel, bin.lower), xEnd: .value(statisticLabel, bin.upper),
                              yStart: .value("Count", 0), yEnd: .value("Count", bin.count))
                    .foregroundStyle(.tint.opacity(0.7))
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
        .chartYAxisLabel("Count")
    }

    private var trace: some View {
        Chart {
            ForEach(tracePoints) { point in
                LineMark(x: .value("Permutations", point.done), y: .value("P", point.p))
            }
            RuleMark(y: .value("Floor", 1 / Double(total + 1)))
                .foregroundStyle(.secondary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        .chartXScale(domain: 0...max(total, 1))
        .chartYScale(domain: 0...traceCeiling)
        .chartXAxisLabel("Permutations")
        .chartYAxisLabel("P")
    }

    // MARK: - Numbers

    private func isExtreme(_ value: Double) -> Bool {
        switch direction {
        case .greaterOrEqual: value >= observed
        case .lessOrEqual: value <= observed
        case .notEqualTo: abs(value) >= abs(observed)
        }
    }

    /// How a permuted value compares with the observed one to count as extreme.
    private var comparison: String {
        switch direction {
        case .greaterOrEqual: "≥"
        case .lessOrEqual: "≤"
        case .notEqualTo: "as extreme as"
        }
    }

    private var extremeCount: Int {
        values.reduce(0) { $0 + (isExtreme($1) ? 1 : 0) }
    }

    /// P from the values so far, as `NullDistributionResult` computes it.
    private var pValue: Double {
        NullDistributionResult(analysisType: AnalysisTag("null"), observed: observed, values: values)
            .pValue(direction: direction)
    }

    private var xDomain: ClosedRange<Double> {
        let low = min(values.min() ?? observed, observed)
        let high = max(values.max() ?? observed, observed)
        let pad = high > low ? (high - low) * 0.05 : max(abs(observed) * 0.1, 0.01)
        return (low - pad)...(high + pad)
    }

    private var bins: [Bin] {
        guard let low = values.min(), let high = values.max() else { return [] }
        let width = high > low ? (high - low) / Double(Self.binCount) : max(abs(low) * 0.01, 1e-6)
        let count = high > low ? Self.binCount : 1
        var counts = [Int](repeating: 0, count: count)
        for value in values {
            counts[min(count - 1, Int((value - low) / width))] += 1
        }
        return counts.indices.map { i in
            Bin(id: i, lower: low + Double(i) * width, upper: low + Double(i + 1) * width, count: counts[i])
        }
    }

    private var tracePoints: [TracePoint] {
        guard !values.isEmpty else { return [] }
        let stride = max(1, values.count / Self.tracePoints)
        var points: [TracePoint] = []
        var extreme = 0
        for (index, value) in values.enumerated() {
            if isExtreme(value) { extreme += 1 }
            let done = index + 1
            if done.isMultiple(of: stride) || done == values.count {
                points.append(TracePoint(done: done, p: Double(extreme + 1) / Double(done + 1)))
            }
        }
        return points
    }

    /// The top of the P axis: room for the trace's largest P, at least 0.1.
    private var traceCeiling: Double {
        min(1, max(0.1, (tracePoints.map(\.p).max() ?? 0) * 1.1))
    }

    private static func format(_ value: Double) -> String {
        guard value.isFinite else { return "–" }
        return abs(value) < 0.001 && value != 0 ? String(format: "%.2e", value) : String(format: "%.4f", value)
    }
}

// MARK: - Previews

#Preview("Running") {
    var rng = SplitMix64(seed: 3)
    let values = (0..<400).map { _ in Double(rng.next() % 1000) / 1000 * 0.02 }
    NullDistributionView(observed: 0.015, values: values, total: 999, statisticLabel: "Φ_ST")
        .padding()
        .frame(width: 760)
}

#Preview("Finished, far tail") {
    var rng = SplitMix64(seed: 5)
    let values = (0..<999).map { _ in Double(rng.next() % 1000) / 1000 * 0.01 }
    NullDistributionView(observed: 0.56, values: values, total: 999, statisticLabel: "Φ_ST")
        .padding()
        .frame(width: 760)
}
