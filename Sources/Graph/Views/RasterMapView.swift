//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RasterMapView.swift
//  Graph
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

#if !os(watchOS)
import Matrix
import SwiftUI

/// A satellite map with a raster layer drawn over it and, optionally, a spatial graph on top.
///
/// Missing cells are transparent, so the imagery shows through them. The map opens framed on the raster.
///
/// ```swift
/// let elevation = try importGeoTIFF(contentsOf: url, cropTo: graph.studyArea())
/// RasterMapView(raster: elevation, graph: graph)
/// ```
public struct RasterMapView: View {
    /// The raster to draw.
    public let raster: Raster
    /// A graph to draw over the raster, or `nil` for the raster alone.
    public let graph: Graph?
    /// The colours for low to high values.
    public let colorRamp: RasterColorRamp
    /// The values at the ends of the colour ramp, or `nil` for the raster's own range.
    public let valueRange: ClosedRange<Float>?
    /// The raster's opacity, from 0 to 1.
    public let opacity: Double

    // MARK: - Initialization

    /// Creates a map of a raster.
    ///
    /// - Parameters:
    ///   - raster: The raster to draw.
    ///   - graph: A graph to draw over it (default `nil`).
    ///   - colorRamp: The colours for low to high values (default `.terrain`).
    ///   - valueRange: The values at the ends of the ramp (default `nil`, the raster's own range).
    ///   - opacity: The raster's opacity, from 0 to 1 (default `0.7`).
    public init(raster: Raster,
                graph: Graph? = nil,
                colorRamp: RasterColorRamp = .terrain,
                valueRange: ClosedRange<Float>? = nil,
                opacity: Double = 0.7) {
        self.raster = raster
        self.graph = graph
        self.colorRamp = colorRamp
        self.valueRange = valueRange
        self.opacity = opacity
    }

    // MARK: - Body

    public var body: some View {
        RasterMapRepresentable(raster: raster, graph: graph, colorRamp: colorRamp, valueRange: valueRange,
                               opacity: opacity)
            .overlay(alignment: .bottomTrailing) {
                if let range = valueRange ?? raster.valueRange {
                    RasterLegend(name: raster.name, colorRamp: colorRamp, range: range)
                        .padding()
                }
            }
    }
}

// MARK: - RasterLegend

/// The layer name over a colour bar labelled with its lowest and highest values.
private struct RasterLegend: View {
    let name: String
    let colorRamp: RasterColorRamp
    let range: ClosedRange<Float>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.caption.bold())
            LinearGradient(stops: colorRamp.stops.map {
                Gradient.Stop(color: Color(red: $0.red, green: $0.green, blue: $0.blue), location: $0.position)
            }, startPoint: .leading, endPoint: .trailing)
            .frame(width: 160, height: 10)
            .clipShape(.rect(cornerRadius: 2))
            HStack {
                Text(range.lowerBound, format: .number.precision(.significantDigits(4)))
                Spacer()
                Text(range.upperBound, format: .number.precision(.significantDigits(4)))
            }
            .font(.caption2.monospacedDigit())
        }
        .frame(width: 160)
        .padding(8)
        .background(.regularMaterial, in: .rect(cornerRadius: 8))
    }
}

// MARK: - Previews

#Preview("Baja elevation under lophoGraph, adjustable opacity") {
    // Held in state so moving the slider doesn't reload the DEM or the graph.
    @Previewable @State var raster = Raster.bajaElevation
    @Previewable @State var graph = Graph.lophoGraph
    @Previewable @State var opacity = 0.7
    RasterMapView(raster: raster, graph: graph, opacity: opacity)
        .overlay(alignment: .bottomLeading) {
            RasterOpacitySlider(opacity: $opacity)
                .padding()
        }
}

#Preview("Baja elevation, viridis") {
    RasterMapView(raster: .bajaElevation, colorRamp: .viridis, opacity: 0.9)
}
#endif
