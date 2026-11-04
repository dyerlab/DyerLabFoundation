//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RasterColorRamp.swift
//  Matrix
//
//  Colours are plain RGB components rather than SwiftUI `Color`s so the ramp
//  and the image it makes stay in this UI-free target. Map views in Graph
//  draw the `CGImage`.
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import CoreGraphics
import Foundation

/// A continuous colour scale for drawing a ``Raster``.
public struct RasterColorRamp: Sendable, Equatable, Hashable {

    /// One colour on the ramp.
    public struct Stop: Sendable, Equatable, Hashable {
        /// Where the colour sits on the ramp, from 0 (lowest value) to 1 (highest).
        public let position: Double
        /// The red component, 0 to 1.
        public let red: Double
        /// The green component, 0 to 1.
        public let green: Double
        /// The blue component, 0 to 1.
        public let blue: Double

        /// Creates a colour stop.
        ///
        /// - Parameters:
        ///   - position: Where the colour sits on the ramp, from 0 to 1.
        ///   - red: The red component, 0 to 1.
        ///   - green: The green component, 0 to 1.
        ///   - blue: The blue component, 0 to 1.
        public init(_ position: Double, red: Double, green: Double, blue: Double) {
            self.position = position
            self.red = red
            self.green = green
            self.blue = blue
        }
    }

    /// The colour stops, in increasing position.
    public let stops: [Stop]

    /// Creates a ramp from colour stops.
    ///
    /// - Parameter stops: At least two stops; they're sorted by position.
    /// - Returns: `nil` if there are fewer than two stops.
    public init?(stops: [Stop]) {
        guard stops.count >= 2 else { return nil }
        self.stops = stops.sorted { $0.position < $1.position }
    }

    /// Green lowlands through tan to white peaks, for elevation.
    public static let terrain = RasterColorRamp(stops: [
        Stop(0.00, red: 0.20, green: 0.50, blue: 0.25),
        Stop(0.35, red: 0.60, green: 0.75, blue: 0.40),
        Stop(0.65, red: 0.80, green: 0.70, blue: 0.50),
        Stop(0.85, red: 0.60, green: 0.45, blue: 0.35),
        Stop(1.00, red: 0.97, green: 0.97, blue: 0.97),
    ])!

    /// The viridis scale (dark purple to yellow), perceptually uniform and readable with colour-vision deficiency.
    public static let viridis = RasterColorRamp(stops: [
        Stop(0.00, red: 0.267, green: 0.005, blue: 0.329),
        Stop(0.25, red: 0.229, green: 0.322, blue: 0.546),
        Stop(0.50, red: 0.128, green: 0.567, blue: 0.551),
        Stop(0.75, red: 0.369, green: 0.789, blue: 0.383),
        Stop(1.00, red: 0.993, green: 0.906, blue: 0.144),
    ])!

    /// Black to white.
    public static let grayscale = RasterColorRamp(stops: [
        Stop(0, red: 0, green: 0, blue: 0),
        Stop(1, red: 1, green: 1, blue: 1),
    ])!

    /// The colour at a position on the ramp.
    ///
    /// - Parameter position: The position, clamped to 0…1.
    /// - Returns: The interpolated red, green and blue components, each 0 to 1.
    public func color(at position: Double) -> (red: Double, green: Double, blue: Double) {
        let t = min(max(position.isNaN ? 0 : position, 0), 1)
        guard let upperIndex = stops.firstIndex(where: { $0.position >= t }) else {
            let last = stops[stops.count - 1]
            return (last.red, last.green, last.blue)
        }
        let upper = stops[upperIndex]
        guard upperIndex > 0, upper.position > stops[upperIndex - 1].position else {
            return (upper.red, upper.green, upper.blue)
        }
        let lower = stops[upperIndex - 1]
        let f = (t - lower.position) / (upper.position - lower.position)
        return (lower.red + f * (upper.red - lower.red),
                lower.green + f * (upper.green - lower.green),
                lower.blue + f * (upper.blue - lower.blue))
    }

    /// Draws a raster as an image, one pixel per cell, with missing cells transparent.
    ///
    /// - Parameters:
    ///   - raster: The raster to draw.
    ///   - valueRange: The values mapped to the ends of the ramp. Defaults to the raster's own range.
    /// - Returns: The image, or `nil` if every cell is missing and no range was given.
    public func makeImage(raster: Raster, valueRange: ClosedRange<Float>? = nil) -> CGImage? {
        makeImage(raster: raster, valueRange: valueRange, width: raster.cols, height: raster.rows) { row, col in
            row * raster.cols + col
        }
    }

    /// Draws a raster resampled onto another grid, such as a map view's projection.
    ///
    /// Each image pixel takes the value of the cell `cellIndex` names, so the caller decides how pixels map to
    /// cells (nearest-neighbour, which keeps categorical layers intact). Pixels with no cell, or a missing one,
    /// are transparent.
    ///
    /// - Parameters:
    ///   - raster: The raster to draw.
    ///   - valueRange: The values mapped to the ends of the ramp. Defaults to the raster's own range.
    ///   - width: The image width, in pixels.
    ///   - height: The image height, in pixels.
    ///   - cellIndex: For an image pixel's row (0 at the top) and column, the index in `raster.values` of the
    ///     cell to draw there, or `nil` for none.
    /// - Returns: The image, or `nil` if every cell is missing and no range was given, or the size isn't positive.
    public func makeImage(raster: Raster,
                          valueRange: ClosedRange<Float>? = nil,
                          width: Int,
                          height: Int,
                          cellIndex: (_ row: Int, _ col: Int) -> Int?) -> CGImage? {
        guard width > 0, height > 0, let range = valueRange ?? raster.valueRange else { return nil }
        // A 256-entry lookup table keeps per-cell work to one index, which matters for millions of cells.
        let table: [(UInt8, UInt8, UInt8)] = (0 ..< 256).map { index in
            let color = color(at: Double(index) / 255)
            return (UInt8((color.red * 255).rounded()), UInt8((color.green * 255).rounded()),
                    UInt8((color.blue * 255).rounded()))
        }
        let span = range.upperBound - range.lowerBound
        var pixels = [UInt8](repeating: 0, count: height * width * 4)
        for row in 0 ..< height {
            for col in 0 ..< width {
                guard let index = cellIndex(row, col), raster.values.indices.contains(index) else { continue }
                let value = raster.values[index]
                guard !value.isNaN else { continue }
                let position = span > 0 ? (value - range.lowerBound) / span : 0.5
                let (red, green, blue) = table[Int((min(max(position, 0), 1) * 255).rounded())]
                let offset = (row * width + col) * 4
                pixels[offset] = red
                pixels[offset + 1] = green
                pixels[offset + 2] = blue
                pixels[offset + 3] = 255
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
