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
//  DistributionPlot.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026-02-16.
//

import Charts
import SwiftUI

/// An area chart showing a frequency distribution with optional vertical reference line.
///
/// Generalizes patterns like Likert-comparison charts. Supply ``DataPoint`` values where
/// `xValue` is the domain value and `yValue` is the frequency count.
public struct DistributionPlot: View {
    public var data: [DataPoint]
    public var xLabel: String
    public var yLabel: String
    public var fillColor: Color
    public var referenceLine: Double?
    public var referenceLabel: String?
    public var referenceColor: Color
    public var xDomain: ClosedRange<Double>?

    public init(data: [DataPoint],
                xLabel: String = "Value",
                yLabel: String = "Frequency",
                fillColor: Color = .blue.opacity(0.3),
                referenceLine: Double? = nil,
                referenceLabel: String? = nil,
                referenceColor: Color = .red,
                xDomain: ClosedRange<Double>? = nil) {
        self.data = data
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.fillColor = fillColor
        self.referenceLine = referenceLine
        self.referenceLabel = referenceLabel
        self.referenceColor = referenceColor
        self.xDomain = xDomain
    }

    private var paddedData: [DataPoint] {
        guard let first = data.first, let last = data.last else { return data }
        var result = [DataPoint]()
        result.append(DataPoint(x: first.xValue - 0.5, y: 0))
        result.append(contentsOf: data)
        result.append(DataPoint(x: last.xValue + 0.5, y: 0))
        return result
    }

    @ChartContentBuilder
    private var chartContent: some ChartContent {
        ForEach(paddedData) { item in
            AreaMark(
                x: .value(xLabel, item.xValue),
                y: .value(yLabel, item.yValue)
            )
            .foregroundStyle(fillColor)
            .interpolationMethod(.catmullRom)
        }

        if let referenceLine {
            RuleMark(x: .value("Reference", referenceLine))
                .foregroundStyle(referenceColor)
                .lineStyle(.init(dash: [5.0, 3.0]))
                .annotation(position: .top, alignment: .trailing) {
                    if let referenceLabel {
                        Text(referenceLabel)
                            .font(.caption)
                            .foregroundStyle(referenceColor)
                    }
                }
        }
    }

    public var body: some View {
        chartView
    }

    @ViewBuilder
    private var chartView: some View {
        let chart = Chart { chartContent }
            .chartXAxisLabel(position: .bottom, alignment: .center) {
                Text(xLabel).font(.title3)
            }
            .chartYAxisLabel(position: .trailing, alignment: .center) {
                Text(yLabel).font(.title3)
            }

        if let xDomain {
            chart.chartXScale(domain: xDomain)
        } else {
            chart
        }
    }
}
#if !SPM_BUILD

#Preview {
    VStack(spacing: 20) {
        DistributionPlot(
            data: [
                DataPoint(x: 1, y: 2),
                DataPoint(x: 2, y: 5),
                DataPoint(x: 3, y: 12),
                DataPoint(x: 4, y: 8),
                DataPoint(x: 5, y: 3)
            ],
            xLabel: "Score",
            yLabel: "Count",
            referenceLine: 3.2,
            referenceLabel: "Mean: 3.2",
            xDomain: 0.5...5.5
        )
        .frame(height: 250)
        .padding()
    }
}
#endif
