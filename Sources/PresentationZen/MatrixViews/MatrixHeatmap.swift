//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MatrixHeatmap.swift
//  PresentationZen
//
//  A matrix drawn as a heatmap: one pixel per cell in an image, scaled up
//  without smoothing, so a thousand-by-thousand distance matrix draws as fast
//  as a small one. The image is made off the main actor whenever the data
//  change. Small matrices are labelled by row; larger ones with groups are
//  labelled by group, with lines where the group changes. Hovering over a
//  cell reads out its row, column and value, and a colour bar gives the scale.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import SwiftUI

/// A heatmap of a matrix, with a colour bar and a hover read-out.
public struct MatrixHeatmap: View {

    /// The most rows labelled by name; beyond this, rows are labelled by group if they have groups.
    private static let labelledRows = 40
    /// The width given to row or group labels.
    private static let labelWidth = 96.0
    /// The width of the colour bar and its numbers.
    private static let legendWidth = 64.0

    /// The matrix.
    public let data: MatrixHeatmapData
    /// The colours values are drawn in.
    public let ramp: RasterColorRamp

    @State private var image: CGImage?
    @State private var hovered: (row: Int, column: Int)?

    /// Creates a heatmap.
    ///
    /// - Parameters:
    ///   - data: The matrix.
    ///   - ramp: The colours values are drawn in (default viridis).
    public init(_ data: MatrixHeatmapData, ramp: RasterColorRamp = .viridis) {
        self.data = data
        self.ramp = ramp
    }

    // MARK: - Body

    /// The heatmap.
    public var body: some View {
        GeometryReader { proxy in
            let side = max(0, min(proxy.size.width - Self.labelWidth - Self.legendWidth - 16, proxy.size.height - 24))
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    labels
                        .frame(width: Self.labelWidth, height: side)
                    cells
                        .frame(width: side, height: side)
                    legend
                        .frame(width: Self.legendWidth, height: side)
                }
                readout
                    .padding(.leading, Self.labelWidth + 8)
            }
        }
        .task(id: data) {
            let data = data
            let ramp = ramp
            image = await Task.detached(priority: .userInitiated) {
                data.valueRange.flatMap {
                    ramp.makeImage(values: data.values, width: data.columnNames.count, height: data.rowNames.count,
                                   valueRange: $0)
                }
            }.value
        }
    }

    // MARK: - Cells

    private var cells: some View {
        ZStack {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.none)
            } else {
                Rectangle().fill(.quaternary)
            }
            groupLines
        }
        .border(.separator)
        .overlay { hoverArea }
    }

    /// Lines where the group changes, across and down.
    private var groupLines: some View {
        Canvas { context, size in
            let runs = data.groupRuns
            guard runs.count > 1 else { return }
            let rows = Double(data.rowNames.count)
            var path = Path()
            for run in runs.dropFirst() {
                let y = Double(run.rows.lowerBound) / rows * size.height
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                if data.isSymmetricInLayout {
                    let x = Double(run.rows.lowerBound) / rows * size.width
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
            }
            context.stroke(path, with: .color(.white.opacity(0.7)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }

    private var hoverArea: some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(.rect)
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        let row = Int(location.y / proxy.size.height * Double(data.rowNames.count))
                        let column = Int(location.x / proxy.size.width * Double(data.columnNames.count))
                        hovered = data.rowNames.indices.contains(row) && data.columnNames.indices.contains(column)
                            ? (row, column) : nil
                    case .ended:
                        hovered = nil
                    }
                }
        }
    }

    // MARK: - Labels

    @ViewBuilder
    private var labels: some View {
        if data.rowNames.count <= Self.labelledRows {
            labelColumn(data.rowNames.enumerated().map { ($0.element, $0.offset..<($0.offset + 1)) })
        } else if data.groupRuns.count <= Self.labelledRows * 2 {
            labelColumn(data.groupRuns.map { ($0.name, $0.rows) })
        } else {
            Color.clear
        }
    }

    /// Labels placed beside the rows they name, right-aligned against the heatmap.
    private func labelColumn(_ items: [(name: String, rows: Range<Int>)]) -> some View {
        GeometryReader { proxy in
            let rowHeight = proxy.size.height / Double(max(data.rowNames.count, 1))
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                // Labels too close together to read are left out.
                if Double(item.rows.count) * rowHeight >= 9 {
                    Text(item.name)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(width: Self.labelWidth, alignment: .trailing)
                        .position(x: Self.labelWidth / 2,
                                  y: (Double(item.rows.lowerBound) + Double(item.rows.count) / 2) * rowHeight)
                }
            }
        }
    }

    // MARK: - Legend and read-out

    private var legend: some View {
        HStack(spacing: 4) {
            LinearGradient(colors: (0...10).reversed().map { step in
                let color = ramp.color(at: Double(step) / 10)
                return Color(red: color.red, green: color.green, blue: color.blue)
            }, startPoint: .top, endPoint: .bottom)
            .frame(width: 12)
            .border(.separator)
            VStack(alignment: .leading) {
                Text(format(data.valueRange?.upperBound))
                Spacer()
                if let units = data.units { Text(units).foregroundStyle(.secondary) }
                Spacer()
                Text(format(data.valueRange?.lowerBound))
            }
            .font(.caption2)
            .monospacedDigit()
        }
    }

    private var readout: some View {
        Group {
            if let hovered {
                Text("\(data.rowNames[hovered.row]) – \(data.columnNames[hovered.column]): "
                     + "\(format(data.value(row: hovered.row, column: hovered.column)))"
                     + (data.units.map { " \($0)" } ?? ""))
            } else {
                Text("\(data.rowNames.count.formatted()) × \(data.columnNames.count.formatted())")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .monospacedDigit()
        .lineLimit(1)
    }

    private func format(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "–" }
        return value.formatted(.number.precision(.fractionLength(abs(value) >= 100 ? 0 : 2)))
    }
}

// MARK: - Previews

#Preview("Small, labelled") {
    let names = ["A", "B", "C", "D", "E"]
    let values = (0..<25).map { Double(abs($0 / 5 - $0 % 5)) * 10 }
    MatrixHeatmap(MatrixHeatmapData(rowNames: names, columnNames: names, values: values, units: "km"))
        .padding()
        .frame(width: 520, height: 420)
}

#Preview("Grouped") {
    let n = 120
    let names = (0..<n).map { "i\($0)" }
    let groups = (0..<n).map { "Pop \($0 / 20)" }
    let values = (0..<(n * n)).map { Double(abs($0 / n / 20 - $0 % n / 20)) * 50 + Double(($0 * 7) % 11) }
    MatrixHeatmap(MatrixHeatmapData(rowNames: names, columnNames: names, values: values, groups: groups, units: "km"))
        .padding()
        .frame(width: 620, height: 520)
}
