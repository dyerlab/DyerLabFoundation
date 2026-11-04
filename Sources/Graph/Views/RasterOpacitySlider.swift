//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RasterOpacitySlider.swift
//  Graph
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

#if !os(watchOS)
import SwiftUI

/// A compact slider for a raster layer's opacity, styled to float over a ``RasterMapView``.
///
/// ```swift
/// @State private var opacity = 0.7
///
/// RasterMapView(raster: elevation, graph: graph, opacity: opacity)
///     .overlay(alignment: .bottomLeading) {
///         RasterOpacitySlider(opacity: $opacity)
///             .padding()
///     }
/// ```
public struct RasterOpacitySlider: View {
    /// The opacity being adjusted, from 0 to 1.
    @Binding public var opacity: Double

    /// Creates an opacity slider.
    ///
    /// - Parameter opacity: The opacity to adjust, from 0 to 1.
    public init(opacity: Binding<Double>) {
        _opacity = opacity
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Opacity \(opacity, format: .percent.precision(.fractionLength(0)))")
                .font(.caption.bold().monospacedDigit())
            Slider(value: $opacity, in: 0 ... 1)
                .frame(width: 160)
        }
        .padding(8)
        .background(.regularMaterial, in: .rect(cornerRadius: 8))
    }
}

#Preview {
    @Previewable @State var opacity = 0.7
    RasterOpacitySlider(opacity: $opacity)
        .padding()
}
#endif
